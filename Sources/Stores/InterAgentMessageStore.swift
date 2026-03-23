import Foundation

/// Represents an inter-agent message waiting for user attention
struct InterAgentMessage: Identifiable {
    let id: UUID
    let fromAgentIndex: Int
    let fromAgentName: String
    let toAgentIndex: Int
    let toAgentName: String
    let message: String
    let receivedAt: Date
}

/// Stores pending inter-agent messages and provides popup state
@Observable
final class InterAgentMessageStore {
    var pending: [InterAgentMessage] = []

    /// Add a new inter-agent message (shows popup)
    func add(fromAgentIndex: Int, fromAgentName: String,
            toAgentIndex: Int, toAgentName: String, message: String) {
        let msg = InterAgentMessage(
            id: UUID(),
            fromAgentIndex: fromAgentIndex,
            fromAgentName: fromAgentName,
            toAgentIndex: toAgentIndex,
            toAgentName: toAgentName,
            message: message,
            receivedAt: Date()
        )
        pending.append(msg)
        print("[InterAgentMessageStore] Added message from \(fromAgentName) to \(toAgentName)")
    }

    /// Dismiss a specific message (hides popup)
    func dismiss(id: UUID) {
        pending.removeAll { $0.id == id }
        print("[InterAgentMessageStore] Dismissed message")
    }

    /// Dismiss all messages for a specific target agent
    func dismissAllForAgent(agentIndex: Int) {
        let before = pending.count
        pending.removeAll { $0.toAgentIndex == agentIndex }
        if pending.count < before {
            print("[InterAgentMessageStore] Dismissed \(before - pending.count) messages for agent \(agentIndex)")
        }
    }

    /// Dismiss the oldest message
    func dismissOldest() {
        if !pending.isEmpty {
            pending.removeFirst()
            print("[InterAgentMessageStore] Dismissed oldest message")
        }
    }
}
