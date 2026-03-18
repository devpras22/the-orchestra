import Foundation

// MARK: - Permission suggestion model (matches Claude Code protocol)

struct PermissionSuggestion: Identifiable {
    let id = UUID()
    let type: String              // "addRules" or "setMode"
    let destination: String?      // "session" or "localSettings"
    let behavior: String?         // "allow" (for addRules)
    let rules: [[String: String]]? // [{toolName, ruleContent}] (for addRules)
    let mode: String?             // e.g. "acceptEdits" (for setMode)

    var displayLabel: String {
        switch type {
        case "addRules":
            guard let firstRule = rules?.first else { return "Always allow" }
            let toolName = firstRule["toolName"] ?? "tool"
            let ruleContent = firstRule["ruleContent"] ?? ""
            // Show a compact version of the rule
            if ruleContent.contains("**") {
                // Path glob like //Users/.../masko-desktop/**
                let short = URL(fileURLWithPath: ruleContent.replacingOccurrences(of: "/**", with: "")).lastPathComponent
                return "Allow \(toolName) in \(short)/"
            } else if !ruleContent.isEmpty {
                // Exact command like "make desktop-build"
                let short = ruleContent.count > 30 ? String(ruleContent.prefix(27)) + "..." : ruleContent
                return "Always allow `\(short)`"
            }
            return "Always allow \(toolName)"
        case "setMode":
            switch mode {
            case "acceptEdits": return "Auto-accept edits"
            case "plan": return "Switch to plan mode"
            default: return mode ?? "Set mode"
            }
        default:
            return type
        }
    }

    /// Convert back to dict for JSON response
    var toDict: [String: Any] {
        var d: [String: Any] = ["type": type]
        if let destination { d["destination"] = destination }
        if let behavior { d["behavior"] = behavior }
        if let rules { d["rules"] = rules }
        if let mode { d["mode"] = mode }
        return d
    }
}

// MARK: - Parsed question models

struct ParsedQuestion {
    let question: String
    let header: String?
    let options: [ParsedOption]
    let multiSelect: Bool
}

struct ParsedOption {
    let label: String
    let description: String?
}

// MARK: - Pending permission

struct PendingPermission: Identifiable {
    let id: UUID
    let event: AgentEvent
    let transport: ResponseTransport
    let receivedAt: Date
    /// tool_use_id correlated from the preceding PreToolUse event
    /// (PermissionRequest events from Claude Code don't include tool_use_id)
    let resolvedToolUseId: String?

    var toolName: String { event.toolName ?? "Unknown" }

    /// Parse permission suggestions from Claude Code protocol
    var permissionSuggestions: [PermissionSuggestion] {
        guard let raw = event.permissionSuggestions else { return [] }
        return raw.compactMap { item -> PermissionSuggestion? in
            guard let dict = item.value as? [String: Any],
                  let type = dict["type"] as? String else { return nil }

            // Parse rules array: [{toolName: String, ruleContent: String}]
            var rules: [[String: String]]?
            if let rawRules = dict["rules"] as? [[String: Any]] {
                rules = rawRules.map { rule in
                    var r: [String: String] = [:]
                    if let t = rule["toolName"] as? String { r["toolName"] = t }
                    if let c = rule["ruleContent"] as? String { r["ruleContent"] = c }
                    return r
                }
            }

            return PermissionSuggestion(
                type: type,
                destination: dict["destination"] as? String,
                behavior: dict["behavior"] as? String,
                rules: rules,
                mode: dict["mode"] as? String
            )
        }
    }

    /// For AskUserQuestion: parse structured questions with options
    var parsedQuestions: [ParsedQuestion]? {
        guard event.toolName == "AskUserQuestion" else { return nil }
        guard let input = event.toolInput else { return nil }
        guard let rawQuestions = input["questions"]?.value else { return nil }

        // Handle both [Any] (from AnyCodable unwrap) and [[String: Any]] casts
        let questionsArray: [Any]
        if let arr = rawQuestions as? [[String: Any]] {
            questionsArray = arr
        } else if let arr = rawQuestions as? [Any] {
            questionsArray = arr
        } else {
            print("[masko-desktop] parsedQuestions: unexpected type for questions: \(type(of: rawQuestions))")
            return nil
        }

        let result = questionsArray.compactMap { element -> ParsedQuestion? in
            // Handle both [String: Any] and [String: AnyCodable]
            let q: [String: Any]
            if let dict = element as? [String: Any] {
                q = dict
            } else if let dict = element as? [String: AnyCodable] {
                q = dict.mapValues(\.value)
            } else {
                return nil
            }

            guard let text = q["question"] as? String else { return nil }
            let header = q["header"] as? String
            let multiSelect = q["multiSelect"] as? Bool ?? false

            // Parse options — handle both [String: Any] and [String: AnyCodable] elements
            let rawOptions: [Any]
            if let opts = q["options"] as? [[String: Any]] {
                rawOptions = opts
            } else if let opts = q["options"] as? [Any] {
                rawOptions = opts
            } else {
                rawOptions = []
            }

            let options = rawOptions.compactMap { optElement -> ParsedOption? in
                let opt: [String: Any]
                if let d = optElement as? [String: Any] {
                    opt = d
                } else if let d = optElement as? [String: AnyCodable] {
                    opt = d.mapValues(\.value)
                } else {
                    return nil
                }
                guard let label = opt["label"] as? String else { return nil }
                return ParsedOption(label: label, description: opt["description"] as? String)
            }
            return ParsedQuestion(question: text, header: header, options: options, multiSelect: multiSelect)
        }
        return result.isEmpty ? nil : result
    }

    var toolInputPreview: String {
        guard let input = event.toolInput else { return "" }
        let raw: String
        // For Bash: show command
        if let command = input["command"]?.value as? String {
            raw = command
        // For Edit/Write: show file path
        } else if let path = input["file_path"]?.value as? String {
            raw = path
        // For Read: show file path
        } else if let path = input["path"]?.value as? String {
            raw = path
        // For AskUserQuestion: show first question text
        } else if let questions = input["questions"]?.value as? [[String: Any]],
                  let firstQ = questions.first,
                  let questionText = firstQ["question"] as? String {
            raw = questionText
        // Fallback: first string value
        } else if let first = input.values.first(where: { ($0.value as? String)?.isEmpty == false }),
                  let str = first.value as? String {
            raw = str
        } else {
            return ""
        }
        // Clean up: strip newlines, limit length
        let clean = raw.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if clean.count > 100 {
            return String(clean.prefix(100)) + "..."
        }
        return clean
    }

    /// Full tool input text without truncation — for expanded view
    var fullToolInputText: String {
        guard let input = event.toolInput else { return "" }
        // Same extraction logic as toolInputPreview but no truncation
        let raw: String
        if let command = input["command"]?.value as? String {
            raw = command
        } else if let content = input["content"]?.value as? String {
            raw = content
        } else if let path = input["file_path"]?.value as? String {
            if let oldStr = input["old_string"]?.value as? String,
               let newStr = input["new_string"]?.value as? String {
                raw = "\(path)\n\n-\(oldStr)\n+\(newStr)"
            } else {
                raw = path
            }
        } else if let questions = input["questions"]?.value as? [[String: Any]] {
            raw = questions.compactMap { q in
                guard let text = q["question"] as? String else { return nil as String? }
                return text
            }.joined(separator: "\n\n")
        } else if let prompt = input["prompt"]?.value as? String {
            raw = prompt
        } else {
            // Dump all string values
            raw = input.compactMap { (key, val) -> String? in
                guard let str = val.value as? String, !str.isEmpty else { return nil }
                return "\(key): \(str)"
            }.joined(separator: "\n")
        }
        return raw.trimmingCharacters(in: .whitespaces)
    }

    /// For ExitPlanMode: read the plan file content from disk
    var planFileContent: String? {
        guard event.toolName == "ExitPlanMode" else { return nil }

        // Try to find plan file path from the transcript
        if let transcriptPath = event.transcriptPath,
           let planPath = Self.findPlanPath(inTranscript: transcriptPath) {
            if let content = try? String(contentsOfFile: planPath, encoding: .utf8) {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Fallback: most recently modified .md scoped to this session's project
        return Self.readLatestPlanFile(projectDir: event.cwd)
    }

    /// Search transcript tail (~64KB) for the plan file path.
    /// Reads only the end of the file to avoid loading multi-MB transcripts into memory.
    private static func findPlanPath(inTranscript path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else { return nil }
        let readSize = min(UInt64(262144), fileSize)  // 256KB — plan path is in system prompt, can be far from tail
        handle.seek(toFileOffset: fileSize - readSize)
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        // Match both global (~/.claude/plans/) and project-specific (~/.claude/projects/.../plans/) paths
        guard let regex = try? NSRegularExpression(pattern: "\\.claude/(?:projects/[^/]+/)?plans/[a-z0-9-]+\\.md") else {
            return nil
        }

        // Search all matches, take the last one (most recent mention)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard let lastMatch = matches.last, let range = Range(lastMatch.range, in: text) else {
            return nil
        }

        let relative = String(text[range])
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fullPath = "\(home)/\(relative)"
        if FileManager.default.fileExists(atPath: fullPath) {
            return fullPath
        }
        return nil
    }

    /// Fallback: read most recently modified plan file, scoped to the session's project when possible.
    /// Claude Code stores project plans in ~/.claude/projects/-<path-with-slashes-replaced-by-dashes>/plans/
    private static func readLatestPlanFile(projectDir: String? = nil) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var candidates: [URL] = []

        // Global plans directory (always searched — plans can live here too)
        let globalDir = home.appendingPathComponent(".claude/plans")
        if let files = try? FileManager.default.contentsOfDirectory(
            at: globalDir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) {
            candidates.append(contentsOf: files.filter { $0.pathExtension == "md" })
        }

        // Project-specific plans — scope to THIS project if cwd is available
        if let cwd = projectDir {
            // Claude Code encodes project dirs as: ~/.claude/projects/-Users-foo-myproject/plans/
            let projectHash = cwd.replacingOccurrences(of: "/", with: "-")
            let projectPlanDir = home.appendingPathComponent(".claude/projects/\(projectHash)/plans")
            if let files = try? FileManager.default.contentsOfDirectory(
                at: projectPlanDir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) {
                candidates.append(contentsOf: files.filter { $0.pathExtension == "md" })
            }
        } else {
            // No cwd — search ALL project plan dirs (original behavior)
            let projectsDir = home.appendingPathComponent(".claude/projects")
            if let projects = try? FileManager.default.contentsOfDirectory(
                at: projectsDir, includingPropertiesForKeys: nil
            ) {
                for project in projects {
                    let plansDir = project.appendingPathComponent("plans")
                    if let files = try? FileManager.default.contentsOfDirectory(
                        at: plansDir, includingPropertiesForKeys: [.contentModificationDateKey]
                    ) {
                        candidates.append(contentsOf: files.filter { $0.pathExtension == "md" })
                    }
                }
            }
        }

        guard !candidates.isEmpty else { return nil }

        let sorted = candidates.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return dateA > dateB
        }

        guard let latest = sorted.first,
              let content = try? String(contentsOf: latest, encoding: .utf8) else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

// MARK: - Store

@Observable
final class PendingPermissionStore {
    private(set) var pending: [PendingPermission] = []
    /// Permissions the user chose to defer ("Later") — hidden from overlay but connection stays open
    private(set) var collapsed: Set<UUID> = []
    /// Shared interaction state per permission — survives expand/collapse transitions
    private var interactionStates: [UUID: PermissionInteractionState] = [:]

    func interactionState(for id: UUID) -> PermissionInteractionState {
        if let existing = interactionStates[id] { return existing }
        let state = PermissionInteractionState()
        interactionStates[id] = state
        return state
    }
    /// Called when a permission is resolved — used to update notification outcome
    var onResolved: ((AgentEvent, ResolutionOutcome) -> Void)?
    /// Called when pending permissions change — used to resize/reposition the overlay panel
    var onPendingChange: (() -> Void)?
    /// Secondary callback for pending changes — used by hotkey manager (avoids overwriting primary)
    var onPendingCountChange: (() -> Void)?
    /// Called by views when a text-input option is selected — activates the app + makes overlay key window
    var onRequestTextInputFocus: (() -> Void)?

    /// Cache PreToolUse toolUseIds to correlate with the next PermissionRequest.
    /// Claude Code fires PreToolUse (with tool_use_id) immediately before PermissionRequest (without it).
    /// Key: "sessionId|agentId|toolName" → toolUseId
    private var preToolUseCache: [String: String] = [:]

    init() {
        startLivenessChecks()
    }

    var count: Int { pending.count }

    /// Cache a PreToolUse event's toolUseId so the next PermissionRequest can be correlated.
    func cachePreToolUse(sessionId: String, agentId: String?, toolName: String, toolUseId: String) {
        let key = "\(sessionId)|\(agentId ?? "")|\(toolName)"
        preToolUseCache[key] = toolUseId
    }

    func add(event: AgentEvent, transport: ResponseTransport) {
        // Correlate with preceding PreToolUse to recover tool_use_id
        // (PermissionRequest events from Claude Code don't include tool_use_id)
        var resolvedToolUseId = event.toolUseId
        if resolvedToolUseId == nil, let sid = event.sessionId, let toolName = event.toolName {
            let key = "\(sid)|\(event.agentId ?? "")|\(toolName)"
            resolvedToolUseId = preToolUseCache.removeValue(forKey: key)
        }

        let permission = PendingPermission(
            id: UUID(),
            event: event,
            transport: transport,
            receivedAt: Date(),
            resolvedToolUseId: resolvedToolUseId
        )
        pending.append(permission)
        onPendingChange?()
        onPendingCountChange?()

        // Monitor transport - if the agent answers from terminal,
        // the transport closes and we auto-dismiss without sending a response.
        transport.onRemoteClose { [weak self] in
            self?.silentRemove(id: permission.id)
        }

        print("[masko-desktop] Permission added: \(event.toolName ?? "unknown") toolUseId=\(resolvedToolUseId ?? "nil") (pending: \(pending.count))")
    }

    func collapse(id: UUID) {
        collapsed.insert(id)
    }

    func expand(id: UUID) {
        collapsed.remove(id)
    }

    /// Periodically check for stale permissions whose transports died silently
    private var livenessTimer: Timer?

    func startLivenessChecks() {
        livenessTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.checkConnectionLiveness() }
        }
    }

    /// Invalidate timers and cancel all open transports - called on app termination
    func stopTimers() {
        livenessTimer?.invalidate()
        livenessTimer = nil
        for perm in pending {
            perm.transport.cancel()
        }
        pending.removeAll()
    }

    deinit {
        livenessTimer?.invalidate()
    }

    private func checkConnectionLiveness() {
        let staleIds = pending.compactMap { perm -> UUID? in
            perm.transport.isAlive ? nil : perm.id
        }
        for id in staleIds {
            silentRemove(id: id)
        }
    }

    /// Dismiss all pending permissions for a session (user answered from terminal).
    /// Called when we receive any non-PermissionRequest event for a session that still has pending permissions.
    func dismissForSession(_ sessionId: String) {
        let matching = pending.filter { $0.event.sessionId == sessionId }
        for perm in matching {
            silentRemove(id: perm.id)
        }
    }

    /// Dismiss pending permissions for a specific agent context within a session.
    /// Matches by sessionId AND agentId so subagent events don't dismiss other agents' permissions.
    func dismissForAgent(sessionId: String, agentId: String?) {
        let matching = pending.filter {
            $0.event.sessionId == sessionId && $0.event.agentId == agentId
        }
        for perm in matching {
            silentRemove(id: perm.id)
        }
    }

    /// Dismiss a single pending permission by its toolUseId.
    /// Used when a postToolUse event arrives — only the specific tool that completed should be dismissed,
    /// not all permissions for the agent (which would incorrectly remove unrelated pending permissions).
    /// Matches on both event.toolUseId and resolvedToolUseId (correlated from PreToolUse).
    func dismissByToolUseId(sessionId: String, toolUseId: String) {
        guard let perm = pending.first(where: {
            $0.event.sessionId == sessionId &&
            ($0.event.toolUseId == toolUseId || $0.resolvedToolUseId == toolUseId)
        }) else { return }
        silentRemove(id: perm.id)
    }

    /// Remove a permission silently (answered from terminal or connection closed)
    private func silentRemove(id: UUID) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let permission = pending[index]

        collapsed.remove(id)
        interactionStates.removeValue(forKey: pending[index].id)
        pending.remove(at: index)
        onPendingChange?()
        onPendingCountChange?()
        onResolved?(permission.event, .unknown)
        print("[masko-desktop] Permission auto-dismissed (answered from terminal): \(permission.toolName) (remaining: \(pending.count))")
    }

    func resolve(id: UUID, decision: PermissionDecision, isExpired: Bool = false) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let permission = pending[index]

        collapsed.remove(id)

        permission.transport.sendDecision(decision)

        interactionStates.removeValue(forKey: pending[index].id)
        pending.remove(at: index)
        onPendingChange?()
        onPendingCountChange?()
        let outcome: ResolutionOutcome = isExpired ? .expired : (decision == .allow ? .allowed : .denied)
        onResolved?(permission.event, outcome)
        print("[masko-desktop] Permission resolved: \(decision) for \(permission.toolName) (remaining: \(pending.count))")
    }

    /// Resolve AskUserQuestion with pre-filled answers via updatedInput
    func resolveWithAnswers(id: UUID, answers: [String: String]) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let permission = pending[index]

        collapsed.remove(id)

        // Build updatedInput with original questions + answers
        var updatedInput: [String: Any] = [:]
        if let originalInput = permission.event.toolInput {
            for (key, val) in originalInput {
                updatedInput[key] = val.value
            }
        }
        updatedInput["answers"] = answers

        permission.transport.sendAllowWithUpdatedInput(updatedInput)

        interactionStates.removeValue(forKey: pending[index].id)
        pending.remove(at: index)
        onPendingChange?()
        onPendingCountChange?()
        onResolved?(permission.event, .allowed)
        print("[masko-desktop] Permission resolved with answers for \(permission.toolName) (remaining: \(pending.count))")
    }

    /// Resolve with allow + user feedback text (for ExitPlanMode "tell Claude what to change")
    func resolveWithFeedback(id: UUID, feedback: String) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let permission = pending[index]

        collapsed.remove(id)

        var updatedInput: [String: Any] = [:]
        if let originalInput = permission.event.toolInput {
            for (key, val) in originalInput {
                updatedInput[key] = val.value
            }
        }
        updatedInput["userFeedback"] = feedback

        permission.transport.sendAllowWithUpdatedInput(updatedInput)

        interactionStates.removeValue(forKey: pending[index].id)
        pending.remove(at: index)
        onPendingChange?()
        onPendingCountChange?()
        onResolved?(permission.event, .allowed)
        print("[masko-desktop] Permission resolved with feedback for \(permission.toolName) (remaining: \(pending.count))")
    }

    /// Resolve with allow + updatedPermissions (for "always allow" suggestions)
    func resolveWithPermissions(id: UUID, suggestions: [PermissionSuggestion]) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let permission = pending[index]

        collapsed.remove(id)

        let updatedPermissions: [[String: Any]] = suggestions.map { $0.toDict }
        permission.transport.sendAllowWithUpdatedPermissions(updatedPermissions)

        interactionStates.removeValue(forKey: pending[index].id)
        pending.remove(at: index)
        onPendingChange?()
        onPendingCountChange?()
        onResolved?(permission.event, .allowed)
        print("[masko-desktop] Permission resolved with \(suggestions.count) always-allow rules for \(permission.toolName) (remaining: \(pending.count))")
    }

    func resolveAll(decision: PermissionDecision) {
        let ids = pending.map(\.id)
        for id in ids {
            resolve(id: id, decision: decision)
        }
    }

}

enum PermissionDecision: String {
    case allow
    case deny

    var httpResponse: (status: String, body: String, exitCode: Int) {
        switch self {
        case .allow:
            let json = """
            {"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}
            """
            return ("200 OK", json, 0)
        case .deny:
            let json = """
            {"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}
            """
            return ("403 Forbidden", json, 2)
        }
    }
}
