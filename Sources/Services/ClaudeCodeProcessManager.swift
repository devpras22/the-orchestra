import Foundation
import AppKit

/// Agent personality data for CLAUDE.md generation
struct AgentPersonality {
    let agentIndex: Int
    let role: String
    let department: String
    let mission: String
    let personality: String
    let companyName: String
    let companyId: String
}

/// Manages spawning and communicating with Claude Code processes
/// Uses tmux to allow sending messages without window focus
/// Supports multiple agents, each with their own tmux session
@Observable
final class ClaudeCodeProcessManager {
    static let shared = ClaudeCodeProcessManager()

    /// Track running sessions per agent index
    private var runningSessions: Set<Int> = []
    private var terminalWindowIds: [Int: Int] = [:]  // agentIndex -> windowId

    /// Track agent personalities for directory creation
    private var agentPersonalities: [Int: AgentPersonality] = [:]

    /// Base tmux session name
    private let tmuxSessionBase = "orchestra"

    /// Path to tmux executable (cached on first use)
    private var tmuxPath: String?

    private init() {}

    /// Get the base directory for Orchestra app data
    private func getOrchestraBaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("The Orchestra")
    }

    /// Get the agent's working directory
    private func getAgentDirectory(companyId: String, agentIndex: Int) -> URL {
        return getOrchestraBaseDirectory()
            .appendingPathComponent("agents")
            .appendingPathComponent(companyId)
            .appendingPathComponent(String(agentIndex))
    }

    /// Delimiter used to split app-managed content from custom instructions
    private static let customSectionDelimiter = "\n---\n## Custom Instructions\n"

    /// Create CLAUDE.md file with agent personality (only if it doesn't exist)
    private func createAgentCLAUDEmd(personality: AgentPersonality) throws -> URL {
        let dir = getAgentDirectory(companyId: personality.companyId, agentIndex: personality.agentIndex)

        // Create directory structure
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileURL = dir.appendingPathComponent("CLAUDE.md")

        // Don't overwrite if file already exists - preserve customizations
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("[ProcessManager] CLAUDE.md already exists at: \(fileURL.path), keeping it")
            return dir
        }

        // Generate CLAUDE.md content
        let content = generateCLAUDEmdContent(personality: personality)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        print("[ProcessManager] Created CLAUDE.md at: \(fileURL.path)")
        return dir
    }

    /// Update an existing CLAUDE.md file with new personality data
    /// Preserves custom instructions below the delimiter
    func updateAgentCLAUDEmd(personality: AgentPersonality) -> Bool {
        let dir = getAgentDirectory(companyId: personality.companyId, agentIndex: personality.agentIndex)
        let fileURL = dir.appendingPathComponent("CLAUDE.md")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[ProcessManager] CLAUDE.md does not exist at: \(fileURL.path), cannot update")
            return false
        }

        // Preserve custom section below delimiter
        let customSection = readCustomSection(from: fileURL)

        // Generate new managed content
        var content = generateCLAUDEmdContent(personality: personality)

        // Append preserved custom section (or add empty delimiter section)
        content += Self.customSectionDelimiter
        content += customSection

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[ProcessManager] Updated CLAUDE.md at: \(fileURL.path)")
            return true
        } catch {
            print("[ProcessManager] Failed to update CLAUDE.md: \(error)")
            return false
        }
    }

    /// Read the custom section (everything below the delimiter) from an existing CLAUDE.md
    private func readCustomSection(from fileURL: URL) -> String {
        guard let existing = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ""
        }

        if let range = existing.range(of: Self.customSectionDelimiter) {
            let custom = String(existing[range.upperBound...])
            print("[ProcessManager] Preserved custom section (\(custom.count) chars)")
            return custom
        }

        // No delimiter found - this is a legacy file, no custom section to preserve
        return ""
    }

    /// Generate CLAUDE.md content for an agent personality
    /// Includes team directory with all other agents for inter-agent communication
    private func generateCLAUDEmdContent(personality: AgentPersonality) -> String {
        // Build team directory section
        var teamSection = ""
        let teammates = agentPersonalities.values.filter { $0.agentIndex != personality.agentIndex && $0.companyId == personality.companyId }

        if !teammates.isEmpty {
            teamSection = "\n## Team Communication\n\nYou can send messages to other team members. Write `@AgentName: your message` on its own line.\n\nYour teammates:\n"
            for teammate in teammates.sorted(by: { $0.agentIndex < $1.agentIndex }) {
                teamSection += "- **\(teammate.role)** (Agent \(teammate.agentIndex)) - \(teammate.mission)\n"
            }
        }

        return """
        # \(personality.role)

        You are **\(personality.role)** at **\(personality.companyName)**.

        - **Department:** \(personality.department)
        - **Mission:** \(personality.mission)
        - **Personality:** \(personality.personality)
        \(teamSection)
        You are part of a team of AI assistants helping a young user learn to direct AI agents.
        Stay in character and be helpful, friendly, and encouraging.

        When working on tasks, remember your role and mission. Communicate in a way that fits your personality.
        """
    }

    /// Find an agent index by name (case-insensitive partial match on role)
    func findAgentIndex(byName name: String, excludingIndex: Int? = nil) -> Int? {
        let nameLower = name.lowercased().trimmingCharacters(in: .whitespaces)
        for (index, personality) in agentPersonalities {
            if let excluding = excludingIndex, index == excluding { continue }
            let roleLower = personality.role.lowercased()
            if roleLower.contains(nameLower) || nameLower.contains(roleLower) {
                return index
            }
        }
        return nil
    }

    /// Get all known agent personalities (read-only)
    func getAgentPersonalities() -> [Int: AgentPersonality] {
        return agentPersonalities
    }

    /// Regenerate CLAUDE.md files for all agents in a team
    /// Preserves custom sections below the delimiter
    func regenerateTeamCLAUDEmds(companyId: String) {
        let teamAgents = agentPersonalities.values.filter { $0.companyId == companyId }
        for agent in teamAgents {
            let _ = updateAgentCLAUDEmd(personality: agent)
        }
        if !teamAgents.isEmpty {
            print("[ProcessManager] Regenerated CLAUDE.md for \(teamAgents.count) agents in team \(companyId)")
        }
    }

    /// Get tmux session name for a specific agent
    private func sessionName(for agentIndex: Int) -> String {
        return "\(tmuxSessionBase)-\(agentIndex)"
    }

    /// Check if any session is running (for backwards compatibility)
    var isRunning: Bool {
        return !runningSessions.isEmpty
    }

    /// Get the path to tmux executable
    /// Checks bundled version first, then falls back to system locations
    private func getTmuxPath() -> String? {
        if let cached = tmuxPath { return cached }

        // First, check for bundled tmux in app resources
        var bundledPaths: [String] = []

        // SPM bundle path (when running via swift run)
        let cwd = FileManager.default.currentDirectoryPath
        bundledPaths.append("\(cwd)/Sources/bin/tmux")
        bundledPaths.append("\(cwd)/.build/arm64-apple-macosx/debug/the-orchestra_the-orchestra.bundle/bin/tmux")

        // Check Bundle.main (when running as built app)
        if let resourcePath = Bundle.main.resourcePath {
            bundledPaths.append("\(resourcePath)/bin/tmux")
        }

        // Check Bundle.module (SPM resources)
        #if SWIFT_PACKAGE
        if let moduleResourcePath = Bundle.module.resourcePath {
            bundledPaths.append("\(moduleResourcePath)/bin/tmux")
        }
        #endif

        // Check bundled locations first
        for path in bundledPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                tmuxPath = path
                print("[ProcessManager] Found bundled tmux at: \(path)")
                return path
            }
        }

        // Fall back to system locations
        let systemPaths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        for path in systemPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                tmuxPath = path
                print("[ProcessManager] Found system tmux at: \(path)")
                return path
            }
        }

        print("[ProcessManager] tmux not found in any location")
        return nil
    }

    /// Open Terminal.app with Claude Code running inside tmux for a specific agent
    /// Terminal window is hidden immediately after opening
    /// Runs on background queue to avoid blocking UI
    @discardableResult
    func spawn(agentIndex: Int, personality: AgentPersonality? = nil) -> Bool {
        // Store personality for this agent
        if let personality = personality {
            agentPersonalities[agentIndex] = personality
        }

        // Check if already running for this agent
        if runningSessions.contains(agentIndex) {
            print("[ProcessManager] Terminal for agent \(agentIndex) already open")
            return true
        }

        // Check if tmux is installed
        guard let tmux = getTmuxPath() else {
            print("[ProcessManager] tmux not installed!")
            return false
        }

        let session = sessionName(for: agentIndex)

        // Determine working directory
        let workingDir: String
        if let personality = agentPersonalities[agentIndex] {
            do {
                // Create agent directory and CLAUDE.md
                let agentDir = try createAgentCLAUDEmd(personality: personality)
                workingDir = agentDir.path
            } catch {
                print("[ProcessManager] Failed to create agent directory: \(error)")
                // Fall back to default directory
                workingDir = FileManager.default.currentDirectoryPath
            }
        } else {
            // No personality, use current directory
            workingDir = FileManager.default.currentDirectoryPath
        }

        // Kill any existing tmux session for this agent
        _ = runCommand(tmux, args: ["kill-session", "-t", session])

        // AppleScript to open Terminal with tmux running claude, then hide it
        // Use full path to bundled tmux binary
        let script = """
        tell application "Terminal"
            set newTab to do script "cd '\(workingDir)' && \(tmux) new-session -s \(session) claude"
            set windowID to id of window 1
        end tell
        tell application "System Events"
            set visible of process "Terminal" to false
        end tell
        return windowID
        """

        // Run on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let appleScript = NSAppleScript(source: script) else {
                print("[ProcessManager] Failed to create AppleScript")
                return
            }

            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)

            if let error = error {
                print("[ProcessManager] AppleScript error: \(error)")
                return
            }

            // Get the window ID for later reference
            let windowId = result.int32Value
            DispatchQueue.main.async {
                self.terminalWindowIds[agentIndex] = Int(windowId)
                self.runningSessions.insert(agentIndex)
            }

            // Wait for tmux session to start (on background queue, doesn't block UI)
            Thread.sleep(forTimeInterval: 2.0)

            print("[ProcessManager] Spawned hidden tmux session '\(session)' for agent \(agentIndex) in \(workingDir)")
        }

        return true
    }

    /// Legacy spawn for backwards compatibility - spawns agent 1
    @discardableResult
    func spawn() -> Bool {
        return spawn(agentIndex: 1)
    }

    /// Set personality for an agent (call before spawning)
    func setPersonality(_ personality: AgentPersonality) {
        agentPersonalities[personality.agentIndex] = personality
        print("[ProcessManager] Set personality for agent \(personality.agentIndex): \(personality.role)")
    }

    /// Send a message to a specific agent's Claude Code via tmux send-keys
    /// Works regardless of which window is focused
    /// Auto-reopens terminal if it was closed
    /// Runs spawning on background queue to avoid blocking UI
    @discardableResult
    func send(message: String, agentIndex: Int) -> Bool {
        let session = sessionName(for: agentIndex)

        // Check if tmux session exists for this agent
        if !isTmuxSessionActive(session) {
            print("[ProcessManager] tmux session '\(session)' not active, spawning new terminal...")
            runningSessions.remove(agentIndex)
            terminalWindowIds.removeValue(forKey: agentIndex)

            // Run spawn and subsequent send on background queue to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                // Spawn the terminal (this already runs async internally, but we need to wait)
                _ = self.spawnSync(agentIndex: agentIndex)

                // Wait for tmux to be ready
                Thread.sleep(forTimeInterval: 2.0)

                // Now send the message
                self.performSend(message: message, agentIndex: agentIndex, session: session)
            }
            return true
        }

        // Session exists, send directly
        return performSend(message: message, agentIndex: agentIndex, session: session)
    }

    /// Synchronous spawn for internal use (called from background queue)
    private func spawnSync(agentIndex: Int) -> Bool {
        // Check if tmux is installed
        guard let tmux = getTmuxPath() else {
            print("[ProcessManager] tmux not installed!")
            return false
        }

        let session = sessionName(for: agentIndex)

        // Determine working directory
        let workingDir: String
        if let personality = agentPersonalities[agentIndex] {
            do {
                // Create agent directory and CLAUDE.md
                let agentDir = try createAgentCLAUDEmd(personality: personality)
                workingDir = agentDir.path
            } catch {
                print("[ProcessManager] Failed to create agent directory: \(error)")
                workingDir = FileManager.default.currentDirectoryPath
            }
        } else {
            workingDir = FileManager.default.currentDirectoryPath
        }

        // Kill any existing tmux session for this agent
        _ = runCommand(tmux, args: ["kill-session", "-t", session])

        // AppleScript to open Terminal with tmux running claude, then hide it
        // Use full path to bundled tmux binary
        let script = """
        tell application "Terminal"
            set newTab to do script "cd '\(workingDir)' && \(tmux) new-session -s \(session) claude"
            set windowID to id of window 1
        end tell
        tell application "System Events"
            set visible of process "Terminal" to false
        end tell
        return windowID
        """

        guard let appleScript = NSAppleScript(source: script) else {
            print("[ProcessManager] Failed to create AppleScript")
            return false
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            print("[ProcessManager] AppleScript error: \(error)")
            return false
        }

        // Get the window ID for later reference
        let windowId = result.int32Value
        self.terminalWindowIds[agentIndex] = Int(windowId)
        self.runningSessions.insert(agentIndex)

        print("[ProcessManager] Spawned hidden tmux session '\(session)' for agent \(agentIndex) in \(workingDir)")
        return true
    }

    /// Internal method to perform the actual tmux send
    @discardableResult
    private func performSend(message: String, agentIndex: Int, session: String) -> Bool {
        // Escape the message for tmux (handle quotes and special chars)
        let escapedMessage = message
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")

        // Use tmux send-keys to send the message
        guard let tmux = getTmuxPath() else {
            print("[ProcessManager] tmux not available")
            return false
        }

        let success = runCommand(tmux, args: [
            "send-keys",
            "-t", session,
            "-l",  // literal mode - don't interpret special chars
            escapedMessage
        ])

        if success {
            // Send Enter key separately
            _ = runCommand(tmux, args: [
                "send-keys",
                "-t", session,
                "Enter"
            ])
            print("[ProcessManager] Sent message to agent \(agentIndex) via tmux: \(message)")
            return true
        } else {
            print("[ProcessManager] Failed to send message via tmux")
            return false
        }
    }

    /// Legacy send for backwards compatibility - sends to agent 1
    @discardableResult
    func send(message: String) -> Bool {
        return send(message: message, agentIndex: 1)
    }

    /// Stop/close the Terminal and tmux session for a specific agent
    func stop(agentIndex: Int) {
        let session = sessionName(for: agentIndex)

        // Kill the tmux session
        if let tmux = getTmuxPath() {
            _ = runCommand(tmux, args: ["kill-session", "-t", session])
        }

        // Close the Terminal tab/window we opened
        if let windowId = terminalWindowIds[agentIndex] {
            let script = """
            tell application "Terminal"
                close window id \(windowId) saving no
            end tell
            """

            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }

        runningSessions.remove(agentIndex)
        terminalWindowIds.removeValue(forKey: agentIndex)
        print("[ProcessManager] Terminal and tmux session closed for agent \(agentIndex)")
    }

    /// Stop all sessions (called when switching companies or app closes)
    func stopAll() {
        for agentIndex in runningSessions {
            stop(agentIndex: agentIndex)
        }
        print("[ProcessManager] All sessions stopped")
    }

    /// Close sessions for specific agents (when switching agent sets)
    func stopAgents(_ agentIndices: [Int]) {
        for agentIndex in agentIndices {
            if runningSessions.contains(agentIndex) {
                stop(agentIndex: agentIndex)
            }
        }
    }

    /// Check if a specific tmux session is still active
    private func isTmuxSessionActive(_ sessionName: String) -> Bool {
        guard let tmux = getTmuxPath() else { return false }

        // List sessions and check if ours exists
        let output = runCommandWithOutput(tmux, args: ["list-sessions", "-F", "#{session_name}"])

        // Check if our session name is in the output
        if let output = output {
            let sessions = output.split(separator: "\n").map { String($0) }
            return sessions.contains(sessionName)
        }
        return false
    }

    /// Check if tmux is installed (legacy)
    private func checkTmuxInstalled() -> Bool {
        let result = runCommand("/usr/bin/which", args: ["tmux"])
        return result
    }

    /// Run a command and return success status
    @discardableResult
    private func runCommand(_ path: String, args: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("[ProcessManager] Command failed: \(path) \(args) - \(error)")
            return false
        }
    }

    /// Run a command and return its output as string
    private func runCommandWithOutput(_ path: String, args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                return String(data: data, encoding: .utf8)
            }
            return nil
        } catch {
            print("[ProcessManager] Command failed: \(path) \(args) - \(error)")
            return nil
        }
    }
}
