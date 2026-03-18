import Foundation

/// Central event dispatcher that owns all agent adapters.
/// Routes events from any adapter through a unified pipeline.
@Observable
final class MaskoEventBus {
    private(set) var adapters: [AgentAdapter] = []

    /// Called when any adapter produces a non-blocking event
    var onEvent: ((AgentEvent) -> Void)?
    /// Called when any adapter produces a permission request (with transport for responding)
    var onPermissionRequest: ((AgentEvent, ResponseTransport) -> Void)?
    /// Called when any adapter produces a custom input (state machine variables)
    var onInput: ((String, ConditionValue) -> Void)?

    func register(_ adapter: AgentAdapter) {
        adapter.onEvent = { [weak self] event in
            self?.onEvent?(event)
        }
        adapter.onPermissionRequest = { [weak self] event, transport in
            self?.onPermissionRequest?(event, transport)
        }
        adapter.onInput = { [weak self] name, value in
            self?.onInput?(name, value)
        }
        adapters.append(adapter)
    }

    /// Install hooks/plugins for all registered adapters
    func installAll() {
        for adapter in adapters {
            do {
                try adapter.install()
            } catch {
                print("[masko-desktop] Failed to install \(adapter.source.displayName) hooks: \(error)")
            }
        }
    }

    /// Start all registered adapters
    func startAll() {
        for adapter in adapters {
            do {
                try adapter.start()
            } catch {
                print("[masko-desktop] Failed to start \(adapter.source.displayName) adapter: \(error)")
            }
        }
    }

    /// Stop all registered adapters
    func stopAll() {
        for adapter in adapters {
            adapter.stop()
        }
    }

    /// Get a specific adapter by source type
    func adapter(for source: AgentSource) -> AgentAdapter? {
        adapters.first { $0.source == source }
    }
}
