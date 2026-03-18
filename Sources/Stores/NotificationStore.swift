import Foundation

@Observable
final class NotificationStore {
    private(set) var notifications: [AppNotification] = []
    private static let filename = "notifications.json"
    private var persistTimer: Timer?
    private var isDirty = false

    init() {
        notifications = LocalStorage.load([AppNotification].self, from: Self.filename) ?? []
    }

    /// Debounced persist — batches rapid writes
    private func schedulePersist() {
        isDirty = true
        guard persistTimer == nil else { return }
        persistTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.persistTimer = nil
            self?.persistNow()
        }
    }

    private func persistNow() {
        guard isDirty else { return }
        isDirty = false
        LocalStorage.save(notifications, to: Self.filename)
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var pendingApprovalCount: Int {
        notifications.filter {
            $0.category == .permissionRequest && $0.resolutionOutcome == .pending
        }.count
    }

    var recent: [AppNotification] {
        Array(notifications.prefix(10))
    }

    func append(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        // Cap at 500 to avoid unbounded growth
        if notifications.count > 500 {
            notifications.removeLast(notifications.count - 500)
        }
        schedulePersist()
    }

    func markAsRead(_ id: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
            notifications[index].readAt = Date()
            schedulePersist()
        }
    }

    func updateResolution(_ id: UUID, outcome: ResolutionOutcome) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].resolutionOutcome = outcome
            notifications[index].resolvedAt = Date()
            notifications[index].isRead = true
            notifications[index].readAt = notifications[index].readAt ?? Date()
            schedulePersist()
        }
    }

    func markAllAsRead() {
        var changed = false
        for i in notifications.indices where !notifications[i].isRead {
            notifications[i].isRead = true
            notifications[i].readAt = Date()
            changed = true
        }
        if changed { schedulePersist() }
    }
}
