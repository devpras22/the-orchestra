import Foundation

@Observable
final class SessionSwitcherStore {
    private(set) var isActive = false
    private(set) var selectedIndex: Int = 0
    private(set) var sessions: [AgentSession] = []

    /// Called when user taps a row — AppStore wires this to focus terminal + dismiss.
    var onTapConfirm: ((AgentSession) -> Void)?

    func open(sessions: [AgentSession]) {
        // Running sessions first, then by most recently active.
        self.sessions = sessions.sorted {
            if $0.phase == .running && $1.phase != .running { return true }
            if $0.phase != .running && $1.phase == .running { return false }
            return ($0.lastEventAt ?? $0.startedAt) > ($1.lastEventAt ?? $1.startedAt)
        }
        self.selectedIndex = 0 // Start on the most recent session
        self.isActive = true
    }

    func selectNext() {
        guard isActive, !sessions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % sessions.count
    }

    func selectPrevious() {
        guard isActive, !sessions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + sessions.count) % sessions.count
    }

    func selectIndex(_ index: Int) {
        guard isActive, index >= 0, index < sessions.count else { return }
        selectedIndex = index
    }

    var selectedSession: AgentSession? {
        guard isActive, selectedIndex >= 0, selectedIndex < sessions.count else { return nil }
        return sessions[selectedIndex]
    }

    func confirm() -> AgentSession? {
        guard isActive else { return nil }
        let session = selectedSession
        close()
        return session
    }

    /// Select an index and immediately confirm (for tap/click interactions).
    func tapConfirm(index: Int) {
        guard isActive, index >= 0, index < sessions.count else { return }
        selectedIndex = index
        if let session = confirm() {
            onTapConfirm?(session)
        }
    }

    /// Refresh the session list while keeping the current selection if possible.
    func refresh(sessions: [AgentSession]) {
        guard isActive else { return }
        let previousId = selectedSession?.id
        self.sessions = sessions.sorted {
            if $0.phase == .running && $1.phase != .running { return true }
            if $0.phase != .running && $1.phase == .running { return false }
            return ($0.lastEventAt ?? $0.startedAt) > ($1.lastEventAt ?? $1.startedAt)
        }
        if let previousId, let newIdx = self.sessions.firstIndex(where: { $0.id == previousId }) {
            selectedIndex = newIdx
        } else {
            selectedIndex = min(selectedIndex, max(sessions.count - 1, 0))
        }
    }

    func close() {
        isActive = false
        sessions = []
        selectedIndex = 0
    }
}
