import Foundation

@Observable
final class SessionFinishedStore {
    var current: Toast? = nil
    var onDismiss: (() -> Void)?
    private var dismissTimer: Timer?

    struct Toast {
        let sessionId: String
        let projectName: String
    }

    func show(sessionId: String, projectName: String) {
        current = Toast(sessionId: sessionId, projectName: projectName)
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.dismiss() }
        }
    }

    func dismiss() {
        guard current != nil else { return }
        current = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        onDismiss?()
    }
}
