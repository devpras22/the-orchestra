import Foundation

/// A single agent hook event, decoded from the JSON that hook scripts forward.
/// Used by all agent adapters (Claude Code, Copilot, Codex).
struct AgentEvent: Identifiable, Codable {
    let id: UUID
    let hookEventName: String
    let sessionId: String?
    let cwd: String?
    let permissionMode: String?

    // Transcript
    let transcriptPath: String?

    // Tool events
    let toolName: String?
    let toolInput: [String: AnyCodable]?
    let toolResponse: [String: AnyCodable]?
    let toolUseId: String?

    // Notification events
    let message: String?
    let title: String?
    let notificationType: String?

    // Session events
    let source: String?
    let reason: String?
    let model: String?

    // Stop events
    let stopHookActive: Bool?
    let lastAssistantMessage: String?

    // Subagent events
    let agentId: String?
    let agentType: String?

    // Task events
    let taskId: String?
    let taskSubject: String?

    // Permission suggestions (e.g. "always allow in folder")
    let permissionSuggestions: [AnyCodable]?

    // Terminal PID (injected by hook script — walk up process tree to find terminal app)
    let terminalPid: Int?

    // Shell PID (injected by hook script — the zsh/bash PID that VS Code Terminal.processId returns)
    let shellPid: Int?

    // Timestamp (set locally when received)
    let receivedAt: Date

    var eventType: HookEventType? {
        HookEventType(rawValue: hookEventName)
    }

    var projectName: String? {
        cwd.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
    }

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case cwd
        case permissionMode = "permission_mode"
        case transcriptPath = "transcript_path"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResponse = "tool_response"
        case toolUseId = "tool_use_id"
        case message
        case title
        case notificationType = "notification_type"
        case source
        case reason
        case model
        case stopHookActive = "stop_hook_active"
        case lastAssistantMessage = "last_assistant_message"
        case agentId = "agent_id"
        case agentType = "agent_type"
        case taskId = "task_id"
        case taskSubject = "task_subject"
        case permissionSuggestions = "permission_suggestions"
        case terminalPid = "terminal_pid"
        case shellPid = "shell_pid"
        case receivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.hookEventName = try container.decode(String.self, forKey: .hookEventName)
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        self.cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        self.permissionMode = try container.decodeIfPresent(String.self, forKey: .permissionMode)
        self.transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        self.toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        self.toolInput = try container.decodeIfPresent([String: AnyCodable].self, forKey: .toolInput)
        self.toolResponse = try container.decodeIfPresent([String: AnyCodable].self, forKey: .toolResponse)
        self.toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.notificationType = try container.decodeIfPresent(String.self, forKey: .notificationType)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.stopHookActive = try container.decodeIfPresent(Bool.self, forKey: .stopHookActive)
        self.lastAssistantMessage = try container.decodeIfPresent(String.self, forKey: .lastAssistantMessage)
        self.agentId = try container.decodeIfPresent(String.self, forKey: .agentId)
        self.agentType = try container.decodeIfPresent(String.self, forKey: .agentType)
        self.taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        self.taskSubject = try container.decodeIfPresent(String.self, forKey: .taskSubject)
        self.permissionSuggestions = try container.decodeIfPresent([AnyCodable].self, forKey: .permissionSuggestions)
        self.terminalPid = try container.decodeIfPresent(Int.self, forKey: .terminalPid)
        self.shellPid = try container.decodeIfPresent(Int.self, forKey: .shellPid)
        self.receivedAt = Date()
    }

    init(
        hookEventName: String,
        sessionId: String? = nil,
        cwd: String? = nil,
        permissionMode: String? = nil,
        transcriptPath: String? = nil,
        toolName: String? = nil,
        toolInput: [String: AnyCodable]? = nil,
        toolResponse: [String: AnyCodable]? = nil,
        toolUseId: String? = nil,
        message: String? = nil,
        title: String? = nil,
        notificationType: String? = nil,
        source: String? = nil,
        reason: String? = nil,
        model: String? = nil,
        stopHookActive: Bool? = nil,
        lastAssistantMessage: String? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        taskId: String? = nil,
        taskSubject: String? = nil,
        permissionSuggestions: [AnyCodable]? = nil,
        terminalPid: Int? = nil,
        shellPid: Int? = nil
    ) {
        self.id = UUID()
        self.hookEventName = hookEventName
        self.sessionId = sessionId
        self.cwd = cwd
        self.permissionMode = permissionMode
        self.transcriptPath = transcriptPath
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolResponse = toolResponse
        self.toolUseId = toolUseId
        self.message = message
        self.title = title
        self.notificationType = notificationType
        self.source = source
        self.reason = reason
        self.model = model
        self.stopHookActive = stopHookActive
        self.lastAssistantMessage = lastAssistantMessage
        self.agentId = agentId
        self.agentType = agentType
        self.taskId = taskId
        self.taskSubject = taskSubject
        self.terminalPid = terminalPid
        self.shellPid = shellPid
        self.permissionSuggestions = permissionSuggestions
        self.receivedAt = Date()
    }
}
