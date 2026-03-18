import Foundation

/// Protocol that all agent adapters conform to.
/// Each adapter handles: hook/plugin installation, event ingestion, and response transport.
protocol AgentAdapter: AnyObject {
    /// Which agent this adapter handles
    var source: AgentSource { get }

    /// Whether the adapter is actively listening for events
    var isRunning: Bool { get }

    /// Check if the agent CLI is installed on this machine
    func isAvailable() -> Bool

    /// Check if hooks/plugin are registered
    func isRegistered() -> Bool

    /// Install hooks/plugin for this agent
    func install() throws

    /// Uninstall hooks/plugin
    func uninstall()

    /// Start receiving events
    func start() throws

    /// Stop receiving events
    func stop()

    // MARK: - Callbacks (set by MaskoEventBus)

    /// Called when a non-blocking event is received
    var onEvent: ((AgentEvent) -> Void)? { get set }

    /// Called when a permission request is received (with transport for responding)
    var onPermissionRequest: ((AgentEvent, ResponseTransport) -> Void)? { get set }

    /// Called when a custom input is received (state machine variables)
    var onInput: ((String, ConditionValue) -> Void)? { get set }
}
