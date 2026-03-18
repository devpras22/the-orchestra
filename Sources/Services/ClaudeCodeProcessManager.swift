import Foundation
import AppKit

/// Manages spawning and communicating with Claude Code processes
/// Uses tmux to allow sending messages without window focus
/// Supports multiple agents, each with their own tmux session
@Observable
final class ClaudeCodeProcessManager {
    static let shared = ClaudeCodeProcessManager()

    /// Track running sessions per agent index
    private var runningSessions: Set<Int> = []
    private var terminalWindowIds: [Int: Int] = [:]  // agentIndex -> windowId

    /// Base tmux session name
    private let tmuxSessionBase = "orchestra"

    /// Path to tmux executable (cached on first use)
    private var tmuxPath: String?

    private init() {}

    /// Get tmux session name for a specific agent
    private func sessionName(for agentIndex: Int) -> String {
        return "\(tmuxSessionBase)-\(agentIndex)"
    }

    /// Check if any session is running (for backwards compatibility)
    var isRunning: Bool {
        return !runningSessions.isEmpty
    }

    /// Get the path to tmux executable
    private func getTmuxPath() -> String? {
        if let cached = tmuxPath { return cached }

        // Check common locations for tmux
        let paths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                tmuxPath = path
                print("[ProcessManager] Found tmux at: \(path)")
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
    func spawn(agentIndex: Int) -> Bool {
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

        // Kill any existing tmux session for this agent
        _ = runCommand(tmux, args: ["kill-session", "-t", session])

        // AppleScript to open Terminal with tmux running claude, then hide it
        let script = """
        tell application "Terminal"
            set newTab to do script "cd /Users/Pras/Documents/ClaudeCode && tmux new-session -s \(session) claude"
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

            print("[ProcessManager] Spawned hidden tmux session '\(session)' for agent \(agentIndex)")
        }

        return true
    }

    /// Legacy spawn for backwards compatibility - spawns agent 1
    @discardableResult
    func spawn() -> Bool {
        return spawn(agentIndex: 1)
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
                self.spawnSync(agentIndex: agentIndex)

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

        // Kill any existing tmux session for this agent
        _ = runCommand(tmux, args: ["kill-session", "-t", session])

        // AppleScript to open Terminal with tmux running claude, then hide it
        let script = """
        tell application "Terminal"
            set newTab to do script "cd /Users/Pras/Documents/ClaudeCode && tmux new-session -s \(session) claude"
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

        print("[ProcessManager] Spawned hidden tmux session '\(session)' for agent \(agentIndex)")
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
