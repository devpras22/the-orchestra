import SwiftUI

/// Identifies which coding agent produced an event or owns a session.
enum AgentSource: String, Codable, CaseIterable, Identifiable {
    case claudeCode
    case copilot
    case codex
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .copilot: "Copilot CLI"
        case .codex: "Codex"
        case .unknown: "Agent"
        }
    }

    var sfSymbol: String {
        switch self {
        case .claudeCode: "c.circle.fill"
        case .copilot: "chevron.left.forwardslash.chevron.right"
        case .codex: "cube.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var accentColor: Color {
        switch self {
        case .claudeCode: Constants.orangePrimary
        case .copilot: .blue
        case .codex: .green
        case .unknown: .secondary
        }
    }

    /// Parse from the raw `source` string on a hook event.
    init(rawSource: String?) {
        guard let raw = rawSource?.lowercased() else {
            self = .unknown
            return
        }
        switch raw {
        case "claude_code", "claude-code", "claudecode":
            self = .claudeCode
        case "copilot", "copilot_cli", "copilot-cli", "github_copilot":
            self = .copilot
        case "codex", "codex-cli", "codex-desktop":
            self = .codex
        default:
            self = .unknown
        }
    }
}
