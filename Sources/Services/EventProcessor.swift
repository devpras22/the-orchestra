import Foundation

@Observable
final class EventProcessor {
    private let eventStore: EventStore
    private let sessionStore: SessionStore
    private let notificationStore: NotificationStore
    private let notificationService: NotificationService

    init(
        eventStore: EventStore,
        sessionStore: SessionStore,
        notificationStore: NotificationStore,
        notificationService: NotificationService
    ) {
        self.eventStore = eventStore
        self.sessionStore = sessionStore
        self.notificationStore = notificationStore
        self.notificationService = notificationService
    }

    @MainActor func process(_ event: AgentEvent) async {
        eventStore.append(event)
        sessionStore.recordEvent(event)

        if let notification = createNotification(from: event) {
            notificationStore.append(notification)
            await notificationService.show(notification)
        }
    }

    private func createNotification(from event: AgentEvent) -> AppNotification? {
        guard let eventType = event.eventType else { return nil }

        switch eventType {
        case .notification:
            switch event.notificationType {
            case "permission_prompt":
                return AppNotification(
                    title: "Permission Required",
                    body: event.message ?? "Claude Code needs your approval to proceed",
                    category: .permissionRequest,
                    priority: .urgent,
                    sessionId: event.sessionId
                )
            case "idle_prompt":
                return AppNotification(
                    title: "Claude is Waiting",
                    body: event.message ?? "Claude Code has been idle in \(event.projectName ?? "a project")",
                    category: .idleAlert,
                    priority: .high,
                    sessionId: event.sessionId
                )
            case "elicitation_dialog":
                return AppNotification(
                    title: "Input Needed",
                    body: event.message ?? "Claude Code needs your input",
                    category: .elicitationDialog,
                    priority: .high,
                    sessionId: event.sessionId
                )
            default:
                return nil
            }

        case .permissionRequest:
            // For AskUserQuestion: show the actual question text
            let body: String
            if event.toolName == "AskUserQuestion",
               let input = event.toolInput,
               let questions = input["questions"]?.value as? [Any] ?? (input["questions"]?.value as? [[String: Any]]),
               let firstQ = questions.first,
               let qDict = (firstQ as? [String: Any]) ?? (firstQ as? [String: AnyCodable])?.mapValues(\.value),
               let questionText = qDict["question"] as? String {
                body = questionText
            } else {
                body = "Claude wants to use \(event.toolName ?? "a tool") in \(event.projectName ?? "a project")"
            }
            return AppNotification(
                title: event.toolName == "AskUserQuestion" ? "Question" : "Permission Requested",
                body: body,
                category: .permissionRequest,
                priority: .high,
                sessionId: event.sessionId
            )

        case .stop:
            return AppNotification(
                title: "Task Completed",
                body: truncate(event.lastAssistantMessage, maxLength: 100)
                    ?? "Claude Code finished in \(event.projectName ?? "a project")",
                category: .sessionLifecycle,
                priority: .normal,
                sessionId: event.sessionId
            )

        case .postToolUseFailure:
            return AppNotification(
                title: "Tool Failed",
                body: "\(event.toolName ?? "A tool") failed in \(event.projectName ?? "a project")",
                category: .toolFailed,
                priority: .normal,
                sessionId: event.sessionId
            )

        case .taskCompleted:
            return AppNotification(
                title: "Task Completed",
                body: event.taskSubject ?? "A task was completed",
                category: .taskCompleted,
                priority: .normal,
                sessionId: event.sessionId
            )

        case .sessionStart:
            return AppNotification(
                title: "Session Started",
                body: "New session in \(event.projectName ?? "unknown project")",
                category: .sessionLifecycle,
                priority: .low,
                sessionId: event.sessionId
            )

        case .sessionEnd:
            return AppNotification(
                title: "Session Ended",
                body: "Session ended in \(event.projectName ?? "unknown project")",
                category: .sessionLifecycle,
                priority: .low,
                sessionId: event.sessionId
            )

        case .preCompact:
            return AppNotification(
                title: "Context Compacting",
                body: "Claude Code is compacting context in \(event.projectName ?? "a project")",
                category: .sessionLifecycle,
                priority: .low,
                sessionId: event.sessionId
            )

        default:
            return nil
        }
    }

    private func truncate(_ text: String?, maxLength: Int) -> String? {
        guard let text, !text.isEmpty else { return nil }
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength)) + "..."
    }
}
