import AppKit
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private var isAvailable = false

    private override init() {
        super.init()
    }

    /// Returns true if we have a proper app bundle (UNUserNotificationCenter requires one)
    private var hasBundle: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    func requestPermission() async {
        guard hasBundle else {
            print("[masko-desktop] No app bundle — notifications disabled (use Xcode or .app build)")
            return
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isAvailable = granted
    }

    func show(_ notification: AppNotification) async {
        guard isAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body ?? ""
        content.sound = sound(for: notification.category)
        content.categoryIdentifier = notification.category.rawValue

        content.userInfo = [
            "notification_id": notification.id.uuidString,
            "category": notification.category.rawValue,
            "session_id": notification.sessionId ?? ""
        ]

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func sound(for category: NotificationCategory) -> UNNotificationSound {
        switch category {
        case .permissionRequest: .defaultCritical
        case .idleAlert, .elicitationDialog: .default
        default: .default
        }
    }

    // Handle notification tap — bring app to front
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
