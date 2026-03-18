import Foundation
import Network

/// Wraps an NWConnection held open by the Claude Code hook script.
/// The hook script (hook-sender.sh) uses `curl --max-time 120` for PermissionRequest,
/// keeping the TCP connection alive until we send back a decision.
final class HookConnectionTransport: ResponseTransport {
    private let connection: NWConnection

    var capabilities: Set<ResponseCapability> {
        [.permissionResponse, .textInput, .updatedInput, .updatedPermissions]
    }

    var isAlive: Bool {
        switch connection.state {
        case .ready, .preparing, .setup:
            return true
        default:
            return false
        }
    }

    init(connection: NWConnection) {
        self.connection = connection
    }

    func sendDecision(_ decision: PermissionDecision) {
        let (status, body, exitHint) = decision.httpResponse
        let response = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\nX-Exit-Code: \(exitHint)\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
        })
    }

    func sendAllowWithUpdatedInput(_ updatedInput: [String: Any]) {
        let decision: [String: Any] = [
            "behavior": "allow",
            "updatedInput": updatedInput,
        ]
        sendHookResponse(decision: decision)
    }

    func sendAllowWithUpdatedPermissions(_ permissions: [[String: Any]]) {
        let decision: [String: Any] = [
            "behavior": "allow",
            "updatedPermissions": permissions,
        ]
        sendHookResponse(decision: decision)
    }

    func cancel() {
        connection.cancel()
    }

    func onRemoteClose(_ handler: @escaping () -> Void) {
        // State-based monitoring catches cancelled/failed
        connection.stateUpdateHandler = { state in
            switch state {
            case .cancelled, .failed:
                DispatchQueue.main.async { handler() }
            default:
                break
            }
        }
        // Receive-based monitoring catches clean TCP close
        monitorReceive(handler)
    }

    // MARK: - Private

    private func monitorReceive(_ handler: @escaping () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] _, _, isComplete, error in
            if isComplete || error != nil {
                DispatchQueue.main.async { handler() }
            } else {
                self?.monitorReceive(handler)
            }
        }
    }

    private func sendHookResponse(decision: [String: Any]) {
        let hookOutput: [String: Any] = [
            "hookEventName": "PermissionRequest",
            "decision": decision,
        ]
        let responseObj: [String: Any] = ["hookSpecificOutput": hookOutput]

        guard let data = try? JSONSerialization.data(withJSONObject: responseObj),
              let body = String(data: data, encoding: .utf8) else { return }

        let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
        })
    }
}
