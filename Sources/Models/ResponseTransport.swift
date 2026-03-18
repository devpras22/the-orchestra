import Foundation

/// What actions a transport supports - determines which UI buttons to show.
enum ResponseCapability {
    /// Can send allow/deny decisions (Claude Code blocking hooks)
    case permissionResponse
    /// Can send free-text answers (AskUserQuestion)
    case textInput
    /// Can send modified tool input (answers, feedback)
    case updatedInput
    /// Can send "always allow" permission rules
    case updatedPermissions
    /// Fallback: can only focus the terminal window
    case openTerminal
}

/// How the mascot sends responses back to an agent.
/// Each agent adapter provides its own transport implementation.
protocol ResponseTransport: AnyObject {
    var capabilities: Set<ResponseCapability> { get }
    var isAlive: Bool { get }

    /// Send a simple allow/deny decision
    func sendDecision(_ decision: PermissionDecision)
    /// Send allow with modified tool input (answers or feedback)
    func sendAllowWithUpdatedInput(_ updatedInput: [String: Any])
    /// Send allow with "always allow" permission rules
    func sendAllowWithUpdatedPermissions(_ permissions: [[String: Any]])
    /// Cancel/close the transport
    func cancel()
    /// Monitor for remote close (agent answered from terminal)
    func onRemoteClose(_ handler: @escaping () -> Void)
}
