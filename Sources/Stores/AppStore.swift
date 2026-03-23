import AppKit
import Foundation

@Observable
final class AppStore: @unchecked Sendable {
    let eventBus = MaskoEventBus()
    let claudeCodeAdapter = ClaudeCodeAdapter()
    let eventStore = EventStore()
    let sessionStore = SessionStore()
    let notificationStore = NotificationStore()
    let notificationService = NotificationService.shared
    let pendingPermissionStore = PendingPermissionStore()
    let mascotStore = MascotStore()
    // let hotkeyManager = GlobalHotkeyManager()  // Disabled - requires accessibility permission
    let sessionSwitcherStore = SessionSwitcherStore()
    let sessionFinishedStore = SessionFinishedStore()
    let interAgentMessageStore = InterAgentMessageStore()

    private(set) var eventProcessor: EventProcessor!
    private(set) var isReady = false
    private(set) var isRunning = false
    private var lastReconcileDate: Date = .distantPast

    /// Cached IDE detection results — survives across SettingsView recreations.
    /// Updated by SettingsView.task and install/uninstall actions.
    var cachedIDEStatuses: [ExtensionInstaller.IDEStatus] = []

    /// Convenience access to the Claude Code local server for UI status indicators
    var localServer: LocalServer { claudeCodeAdapter.localServer }

    /// Called when an agent event is received - wire to OverlayManager.handleEvent
    var onEventForOverlay: ((AgentEvent) -> Void)?

    /// Called when an agent event is received - forward to WebView
    var onEventForWebView: ((AgentEvent) -> Void)?
    /// Called when a custom input is received via POST /input
    var onInputForOverlay: ((String, ConditionValue) -> Void)?
    /// Called when session phases change outside of events (e.g. interrupt detection via transcript)
    var onRefreshOverlay: (() -> Void)?
    /// Called when the session-finished toast appears/dismisses — trigger panel reposition
    var onToastChanged: (() -> Void)?

    /// Expanded permission panel callback — wire to OverlayManager
    var onExpandPermission: (() -> Void)?

    /// Session switcher overlay callbacks — wire to OverlayManager
    var onSessionSwitcherShow: (() -> Void)?
    var onSessionSwitcherUpdate: (() -> Void)?
    var onSessionSwitcherDismiss: (() -> Void)?

    /// Set by URL handler to navigate to a mascot after install
    var navigateToMascotId: UUID?

    var hasUnreadNotifications: Bool { notificationStore.unreadCount > 0 }

    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    init() {
        self.eventProcessor = EventProcessor(
            eventStore: eventStore,
            sessionStore: sessionStore,
            notificationStore: notificationStore,
            notificationService: notificationService
        )

        // Register adapters with the event bus
        eventBus.register(claudeCodeAdapter)

        // Wire event bus -> event processor + overlay state machine
        eventBus.onEvent = { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                // Forward to WebView for 3D visualization
                self.onEventForWebView?(event)

                await self.eventProcessor.process(event)

                // If a subsequent event arrives for a session with pending permissions,
                // the user may have resolved a permission from the terminal - dismiss it.
                // For postToolUse/postToolUseFailure: only dismiss the SPECIFIC tool use
                // that completed (by toolUseId), not all permissions for the agent.
                // For stop/userPromptSubmit: session is ending, dismiss all for that agent.
                if let eventType = event.eventType,
                   let sid = event.sessionId {
                    // Cache PreToolUse toolUseId - fires immediately before PermissionRequest
                    // for the same tool call, and carries the tool_use_id that PermissionRequest lacks.
                    if eventType == .preToolUse,
                       let toolUseId = event.toolUseId,
                       let toolName = event.toolName {
                        self.pendingPermissionStore.cachePreToolUse(
                            sessionId: sid, agentId: event.agentId,
                            toolName: toolName, toolUseId: toolUseId
                        )
                    }

                    if [.stop, .userPromptSubmit].contains(eventType),
                       self.pendingPermissionStore.pending.contains(where: {
                           $0.event.sessionId == sid && $0.event.agentId == event.agentId
                       }) {
                        self.pendingPermissionStore.dismissForAgent(sessionId: sid, agentId: event.agentId)
                    } else if [.postToolUse, .postToolUseFailure].contains(eventType),
                              let toolUseId = event.toolUseId {
                        self.pendingPermissionStore.dismissByToolUseId(sessionId: sid, toolUseId: toolUseId)
                    }
                }

                // Show "task completed" toast when agent finishes (skip interrupts)
                if event.eventType == .stop,
                   event.reason != "interrupted",
                   !self.pendingPermissionStore.pending.contains(where: { $0.event.sessionId == event.sessionId }) {
                    self.sessionFinishedStore.show(
                        sessionId: event.sessionId ?? "",
                        projectName: event.projectName ?? "Project"
                    )
                    self.syncActiveCard()
                    self.onToastChanged?()
                }

                // Dismiss toast when user starts typing (already back in the loop)
                if event.eventType == .userPromptSubmit {
                    self.sessionFinishedStore.dismiss()
                }

                self.onEventForOverlay?(event)
            }
        }

        // Wire event bus -> custom input endpoint
        eventBus.onInput = { [weak self] name, value in
            guard let self else { return }
            Task { @MainActor in
                self.onInputForOverlay?(name, value)
            }
        }

        // Wire event bus -> permission requests (with transport for responding)
        eventBus.onPermissionRequest = { [weak self] event, transport in
            guard let self else { return }
            Task { @MainActor in
                self.pendingPermissionStore.add(event: event, transport: transport)
            }
        }

        // Wire interrupt detection → overlay refresh + session count sync + switcher refresh
        sessionStore.onPhasesChanged = { [weak self] in
            guard let self else { return }
            self.onRefreshOverlay?()
            // self.hotkeyManager.activeSessionCount = activeCount  // Disabled

            // Auto-dismiss or refresh session switcher when sessions change
            if self.sessionSwitcherStore.isActive {
                let activeCount = self.sessionStore.activeSessions.count
                if activeCount < 2 {
                    self.sessionSwitcherStore.close()
                    self.syncActiveCard()
                    self.onSessionSwitcherDismiss?()
                } else {
                    self.sessionSwitcherStore.refresh(sessions: self.sessionStore.activeSessions)
                    self.onSessionSwitcherUpdate?()
                }
            }
        }

        // Wire pending permission count → sync active card
        pendingPermissionStore.onPendingCountChange = { [weak self] in
            self?.syncActiveCard()
        }

        // Wire session finished toast dismiss → sync active card + panel reposition
        sessionFinishedStore.onDismiss = { [weak self] in
            self?.syncActiveCard()
            self?.onToastChanged?()
        }

        // Set initial count
        // hotkeyManager.activeSessionCount = sessionStore.activeSessions.count  // Disabled

        // Wire session switcher tap-to-confirm (clicked a row)
        sessionSwitcherStore.onTapConfirm = { [weak self] session in
            guard let self else { return }
            self.sessionSwitcherStore.close()
            self.syncActiveCard()
            IDETerminalFocus.focusSession(session)
            self.onSessionSwitcherDismiss?()
        }

        // === HOTKEY MANAGER WIRING DISABLED (requires accessibility) ===
        // All hotkeyManager callbacks commented out

        // Update permission notification with resolution outcome
        pendingPermissionStore.onResolved = { [weak self] event, outcome in
            guard let self else { return }
            for notification in self.notificationStore.notifications where
                notification.resolutionOutcome == .pending &&
                notification.category == .permissionRequest &&
                notification.sessionId == event.sessionId {
                self.notificationStore.updateResolution(notification.id, outcome: outcome)
                break
            }
        }
    }

    /// Recompute which overlay card has priority
    func syncActiveCard() {
        // Simplified - no hotkey manager
    }

    /// Call once from .task {} on the menu bar view
    func start() async {
        guard !isRunning else { return }
        isRunning = true
        eventBus.installAll()

        // Evict cached videos older than 30 days
        VideoCache.shared.evictStaleFiles()

        // Only request permissions if onboarding is done.
        // During onboarding, each permission is requested by its dedicated step.
        if hasCompletedOnboarding {
            // hotkeyManager.start()  // Disabled
            await notificationService.requestPermission()

            // Auto-upgrade IDE extension if a newer version is bundled
            if UserDefaults.standard.bool(forKey: "ideExtensionEnabled") {
                ExtensionInstaller.upgradeIfNeeded()
            }
        }

        eventBus.startAll()

        // Reconcile sessions when app comes to foreground (crash recovery).
        // Throttled to at most once per 30 seconds — this notification fires on every
        // app switch (Cmd+Tab), not just when Masko activates.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                if now.timeIntervalSince(self.lastReconcileDate) >= 30 {
                    self.lastReconcileDate = now
                    self.sessionStore.reconcileIfNeeded()
                }
            }
        }

        // Clean up on app termination to avoid zombie NWListener processes
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }

        isReady = true
    }

    /// Tear down adapters and timers to prevent zombie processes
    func stop() {
        eventBus.stopAll()
        sessionStore.stopTimers()
        pendingPermissionStore.stopTimers()
        // hotkeyManager.stop()  // Disabled
    }
}
