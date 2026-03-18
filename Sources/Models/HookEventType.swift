import Foundation

enum HookEventType: String, Codable, CaseIterable, Identifiable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case permissionRequest = "PermissionRequest"
    case stop = "Stop"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case notification = "Notification"
    case preCompact = "PreCompact"
    case taskCompleted = "TaskCompleted"
    case teammateIdle = "TeammateIdle"
    case configChange = "ConfigChange"
    case worktreeCreate = "WorktreeCreate"
    case worktreeRemove = "WorktreeRemove"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sessionStart: "Session Started"
        case .sessionEnd: "Session Ended"
        case .userPromptSubmit: "Prompt Submitted"
        case .preToolUse: "Tool Starting"
        case .postToolUse: "Tool Completed"
        case .postToolUseFailure: "Tool Failed"
        case .permissionRequest: "Permission Requested"
        case .stop: "Agent Stopped"
        case .subagentStart: "Subagent Started"
        case .subagentStop: "Subagent Stopped"
        case .notification: "Notification"
        case .preCompact: "Context Compacting"
        case .taskCompleted: "Task Completed"
        case .teammateIdle: "Teammate Idle"
        case .configChange: "Config Changed"
        case .worktreeCreate: "Worktree Created"
        case .worktreeRemove: "Worktree Removed"
        }
    }

    var sfSymbol: String {
        switch self {
        case .sessionStart: "play.circle"
        case .sessionEnd: "xmark.circle"
        case .userPromptSubmit: "text.bubble"
        case .preToolUse: "hammer"
        case .postToolUse: "hammer.fill"
        case .postToolUseFailure: "exclamationmark.triangle"
        case .permissionRequest: "hand.raised"
        case .stop: "stop.circle"
        case .subagentStart: "arrow.branch"
        case .subagentStop: "arrow.merge"
        case .notification: "bell"
        case .preCompact: "arrow.triangle.2.circlepath"
        case .taskCompleted: "checkmark.circle"
        case .teammateIdle: "person.crop.circle.badge.clock"
        case .configChange: "gearshape"
        case .worktreeCreate: "folder.badge.plus"
        case .worktreeRemove: "folder.badge.minus"
        }
    }

    var color: String {
        switch self {
        case .notification, .permissionRequest: "orange"
        case .sessionStart, .subagentStart: "green"
        case .sessionEnd, .subagentStop: "red"
        case .stop, .taskCompleted: "blue"
        case .postToolUseFailure: "red"
        case .preToolUse, .postToolUse: "purple"
        default: "secondary"
        }
    }

    var isHighPriority: Bool {
        switch self {
        case .notification, .permissionRequest, .postToolUseFailure: true
        default: false
        }
    }
}
