import Foundation

/// Claude Code adapter - wraps LocalServer + HookInstaller into the AgentAdapter protocol.
/// Claude Code sends events via HTTP hooks to a local server.
final class ClaudeCodeAdapter: AgentAdapter {
    let source: AgentSource = .claudeCode

    /// Exposed for UI status indicators (port number, running state)
    let localServer = LocalServer()

    var isRunning: Bool { localServer.isRunning }

    var onEvent: ((AgentEvent) -> Void)?
    var onPermissionRequest: ((AgentEvent, ResponseTransport) -> Void)?
    var onInput: ((String, ConditionValue) -> Void)?

    func isAvailable() -> Bool {
        let paths = ["/usr/local/bin/claude", "/opt/homebrew/bin/claude"]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) { return true }
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    func isRegistered() -> Bool {
        HookInstaller.isRegistered()
    }

    func install() throws {
        try HookInstaller.install()
    }

    func uninstall() {
        try? HookInstaller.uninstall()
    }

    func start() throws {
        localServer.onEventReceived = { [weak self] event in
            self?.onEvent?(event)
        }
        localServer.onPermissionRequest = { [weak self] event, connection in
            let transport = HookConnectionTransport(connection: connection)
            self?.onPermissionRequest?(event, transport)
        }
        localServer.onInputReceived = { [weak self] name, value in
            self?.onInput?(name, value)
        }
        try localServer.start()
    }

    func stop() {
        localServer.stop()
    }
}
