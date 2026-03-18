import SwiftUI
import WebKit

/// WebView that loads The Delegation's 3D interface
struct OrchestraWebView: NSViewRepresentable {
    @Environment(AppStore.self) var appStore

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.userContentController.add(context.coordinator, name: "orchestra")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Find the web resources - SPM puts them in a bundle
        let possiblePaths = findWebPaths()

        for (htmlPath, webFolder) in possiblePaths {
            if FileManager.default.fileExists(atPath: htmlPath.path) {
                print("[WebView] Loading: \(htmlPath.path)")
                print("[WebView] Web folder: \(webFolder.path)")
                webView.loadFileURL(htmlPath, allowingReadAccessTo: webFolder)
                return webView
            }
        }

        // Fallback
        print("[WebView] HTML not found in any location")
        print("[WebView] Searched: \(possiblePaths.map { $0.0.path })")
        webView.loadHTMLString(errorHTML, baseURL: nil)
        return webView
    }

    private func findWebPaths() -> [(URL, URL)] {
        var paths: [(URL, URL)] = []
        let cwd = FileManager.default.currentDirectoryPath

        // 1. SPM build bundle (most reliable for swift run)
        let spmBundle = URL(fileURLWithPath: cwd)
            .appendingPathComponent(".build/arm64-apple-macosx/debug/the-orchestra_the-orchestra.bundle/web/index.html")
        paths.append((spmBundle, spmBundle.deletingLastPathComponent()))

        // 2. Try Bundle.module (SPM resources)
        #if SWIFT_PACKAGE
        let moduleBundle = Bundle.module
        if let html = moduleBundle.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            paths.append((html, html.deletingLastPathComponent()))
        }
        #endif

        // 3. Main bundle resources
        if let resourcePath = Bundle.main.resourcePath {
            let html = URL(fileURLWithPath: resourcePath).appendingPathComponent("web/index.html")
            paths.append((html, html.deletingLastPathComponent()))
        }

        return paths
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Sync agents when sessions change
        context.coordinator.syncAgents(webView: webView, appStore: appStore)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // Error HTML when files not found
    let errorHTML = """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          background: #1a0a2e;
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          font-family: -apple-system, sans-serif;
          color: #f95d02;
        }
        h1 { font-size: 24px; }
        p { color: #888; margin-top: 10px; }
      </style>
    </head>
    <body>
      <div>
        <h1>🎭 The Orchestra</h1>
        <p>Web resources not found. Please rebuild.</p>
      </div>
    </body>
    </html>
    """

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastSessionIds: Set<String> = []
        weak var webView: WKWebView?
        var appStore: AppStore?
        let processManager = ClaudeCodeProcessManager.shared

        /// Track which session ID belongs to which agent index
        /// Key: sessionId, Value: agentIndex
        private var sessionToAgentMap: [String: Int] = [:]

        /// Track spawn times per agent for session identification
        private var agentSpawnTimes: [Int: Date] = [:]

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "ready":
                print("[WebView] 3D scene ready")
            case "chatMessage":
                // User sent a chat message from UI - forward to Claude Code
                print("[WebView] Received chatMessage body: \(body)")
                if let message = body["message"] as? String,
                   let agentIndex = body["agentIndex"] as? Int {
                    print("[WebView] Chat message for agent \(agentIndex): \(message)")
                    sendToClaudeCode(message: message, agentIndex: agentIndex)
                } else if let message = body["message"] as? String {
                    print("[WebView] Chat message (no agent index, defaulting to 1): \(message)")
                    sendToClaudeCode(message: message, agentIndex: 1)
                }
            case "agentEvent":
                print("[WebView] Agent event: \(body)")
            case "switchCompany":
                // User switched companies - close all tmux sessions
                print("[WebView] Company switch - closing all tmux sessions")
                processManager.stopAll()
                // Reset session tracking
                resetAllSessions()
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[WebView] Page loaded")
            self.webView = webView

            // Inject JavaScript to hook into the Delegation UI and bridge to native
            let bridgeJS = """
            (function() {
                console.log('[Orchestra Bridge] Injecting...');

                // Notify native app that page is ready
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.orchestra) {
                    window.webkit.messageHandlers.orchestra.postMessage({ type: 'ready' });
                    console.log('[Orchestra Bridge] Sent ready');
                }

                // Hook chat input to capture user messages WITH agent index
                document.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter' && !e.shiftKey) {
                        const textarea = document.querySelector('textarea[placeholder*="Message"]');
                        if (textarea && textarea.value.trim()) {
                            // Get the selected NPC index from the UI store
                            let agentIndex = 1; // default
                            if (window.orchestraUIStore) {
                                const state = window.orchestraUIStore.getState();
                                console.log('[Orchestra Bridge] UI Store state:', state);
                                if (state.selectedNpcIndex !== null && state.selectedNpcIndex !== undefined) {
                                    agentIndex = state.selectedNpcIndex;
                                }
                            } else {
                                console.log('[Orchestra Bridge] orchestraUIStore not found on window');
                            }

                            console.log('[Orchestra Bridge] Sending message to agent', agentIndex, ':', textarea.value);
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.orchestra) {
                                window.webkit.messageHandlers.orchestra.postMessage({
                                    type: 'chatMessage',
                                    message: textarea.value,
                                    agentIndex: agentIndex
                                });
                            }
                        }
                    }
                }, true);

                console.log('[Orchestra Bridge] Injection complete');
            })();
            """

            webView.evaluateJavaScript(bridgeJS) { result, error in
                if let error = error {
                    print("[WebView] Bridge injection failed: \(error)")
                } else {
                    print("[WebView] Bridge injected successfully")
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[WebView] Navigation failed: \(error)")
        }

        func syncAgents(webView: WKWebView, appStore: AppStore) {
            self.webView = webView
            self.appStore = appStore

            // Wire up event callback to forward to WebView
            appStore.onEventForWebView = { [weak self] event in
                self?.handleAgentEvent(event)
            }

            let sessions = appStore.sessionStore.activeSessions
            lastSessionIds = Set(sessions.map { $0.id })
        }

        private func handleAgentEvent(_ event: AgentEvent) {
            guard let webView = webView else { return }

            // For SessionStart events, try to identify which agent this session belongs to
            if event.eventType == .sessionStart,
               let sessionId = event.sessionId {
                // Find which agent spawned around this time
                let eventTime = event.receivedAt
                for (agentIndex, spawnTime) in agentSpawnTimes {
                    // If this session started within 5 seconds of spawn, it's for this agent
                    if eventTime >= spawnTime && eventTime.timeIntervalSince(spawnTime) < 5.0 {
                        sessionToAgentMap[sessionId] = agentIndex
                        print("[WebView] Mapped session \(sessionId) to agent \(agentIndex)")
                        break
                    }
                }
            }

            // Determine which agent this event belongs to (if tracked)
            let targetAgentIndex: Int? = {
                guard let sessionId = event.sessionId else { return nil }
                return sessionToAgentMap[sessionId]
            }()

            // UI STATE CHANGES: Only for tracked sessions (agents spawned via tmux)
            if let targetAgentIndex = targetAgentIndex {
                print("[WebView] Processing UI event for agent \(targetAgentIndex): \(event.eventType?.rawValue ?? "unknown")")

                // Event → UI State Mapping:
                // PreToolUse → sit_work animation (agent is thinking/working) in place
                // Stop with message → talk animation (agent is speaking), then idle
                // Stop without message → idle
                if event.eventType == .preToolUse {
                    setAgentThinking(webView: webView, agentIndex: targetAgentIndex, thinking: true)
                } else if event.eventType == .stop {
                    if let assistantMessage = event.lastAssistantMessage, !assistantMessage.isEmpty {
                        // Agent has a response - play talk animation first
                        setAgentTalking(webView: webView, agentIndex: targetAgentIndex)
                        print("[WebView] Received assistant response for agent \(targetAgentIndex): \(assistantMessage.prefix(100))...")
                        sendAssistantMessageToWebView(assistantMessage, agentIndex: targetAgentIndex, webView: webView)
                        // After delay, return to idle and stop speaking
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.setAgentIdle(webView: webView, agentIndex: targetAgentIndex)
                        }
                    } else {
                        // No response - just go idle
                        setAgentIdle(webView: webView, agentIndex: targetAgentIndex)
                    }
                }
            }

            // ACTIVITY LOG: Show ALL events regardless of session tracking
            // For untracked sessions, use agent 1 (first AI agent) as default
            let logAgentIndex = targetAgentIndex ?? 1
            let actionText = formatActionText(event)
            let logEntry = "{ agentIndex: \(logAgentIndex), action: '\(escapeJS(actionText))' }"

            let js = """
            (function() {
              if (window.orchestraStore) {
                const store = window.orchestraStore.getState();
                if (store.addLogEntry) {
                  store.addLogEntry(\(logEntry));
                }
              }
            })();
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("[WebView] Log entry failed: \(error.localizedDescription)")
                    }
                }
            }
        }

        /// Set agent to working animation (sit_work) in place - no walking
        private func setAgentThinking(webView: WKWebView, agentIndex: Int, thinking: Bool) {
            let animation = thinking ? "sit_work" : "idle"
            let js = """
            (function() {
              if (window.orchestraSceneManager && window.orchestraSceneManager.controller) {
                window.orchestraSceneManager.controller.play(\(agentIndex), '\(animation)');
                console.log('[Orchestra] Agent \(agentIndex) \(thinking ? "thinking" : "idle")');
              }
            })();
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("[WebView] Failed to set thinking state: \(error.localizedDescription)")
                    }
                }
            }
        }

        /// Set agent to talk animation (speaking response)
        private func setAgentTalking(webView: WKWebView, agentIndex: Int) {
            let js = """
            (function() {
              if (window.orchestraSceneManager && window.orchestraSceneManager.controller) {
                window.orchestraSceneManager.controller.play(\(agentIndex), 'talk');
                window.orchestraSceneManager.controller.setSpeaking(\(agentIndex), true);
                console.log('[Orchestra] Agent \(agentIndex) talking');
              }
            })();
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("[WebView] Failed to set talking state: \(error.localizedDescription)")
                    }
                }
            }
        }

        /// Set agent back to idle and stop speaking
        private func setAgentIdle(webView: WKWebView, agentIndex: Int) {
            let js = """
            (function() {
              if (window.orchestraSceneManager && window.orchestraSceneManager.controller) {
                window.orchestraSceneManager.controller.play(\(agentIndex), 'idle');
                window.orchestraSceneManager.controller.setSpeaking(\(agentIndex), false);
                console.log('[Orchestra] Agent \(agentIndex) idle');
              }
            })();
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("[WebView] Failed to set idle state: \(error.localizedDescription)")
                    }
                }
            }
        }

        private func sendAssistantMessageToWebView(_ message: String, agentIndex: Int, webView: WKWebView) {
            let escapedMessage = escapeJS(message)

            let js = """
            (function() {
              if (window.orchestraStore) {
                const store = window.orchestraStore.getState();
                store.appendAgentHistory(\(agentIndex), 'assistant', ["\(escapedMessage)"]);
                console.log('[Orchestra] Added assistant message to agent \(agentIndex)');
              } else {
                console.log('[Orchestra] orchestraStore not found on window');
              }
            })();
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("[WebView] Failed to add assistant message: \(error.localizedDescription)")
                    }
                }
            }
        }

        /// Get the first AI agent (non-player) index
        private func getFirstAIAgentIndex(webView: WKWebView) -> Int {
            let js = """
            (function() {
              if (window.useAgencyStore) {
                const store = window.useAgencyStore.getState();
                const agentSetId = store.selectedAgentSetId;
                if (window.AGENT_SETS) {
                  const agentSet = window.AGENT_SETS.find(s => s.id === agentSetId);
                  if (agentSet) {
                    const aiAgent = agentSet.agents.find(a => !a.isPlayer);
                    if (aiAgent) {
                      return aiAgent.index;
                    }
                  }
                }
              }
              return 1;
            })();
            """

            let semaphore = DispatchSemaphore(value: 0)
            var result = 1

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { value, error in
                    if let index = value as? Int {
                        result = index
                    }
                    semaphore.signal()
                }
            }

            _ = semaphore.wait(timeout: .now() + 0.5)
            return result
        }

        private func formatActionText(_ event: AgentEvent) -> String {
            let toolName = event.toolName ?? ""

            switch event.eventType {
            case .preToolUse:
                return "preparing to use \(toolName)"
            case .postToolUse:
                return "completed \(toolName)"
            case .postToolUseFailure:
                return "failed on \(toolName)"
            case .userPromptSubmit:
                return "received user prompt"
            case .stop:
                let reason = event.reason ?? "completed"
                return "session \(reason)"
            case .notification:
                return event.message ?? "notification"
            case .permissionRequest:
                return "needs permission for \(toolName)"
            case .taskCompleted:
                let subject = event.taskSubject ?? "a task"
                return "✅ completed: \(subject)"
            case .sessionStart:
                return "started session"
            default:
                return event.eventType?.rawValue ?? "unknown"
            }
        }

        private func escapeJS(_ str: String) -> String {
            return str
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
        }

        private func sendToClaudeCode(message: String, agentIndex: Int) {
            print("[Coordinator] sendToClaudeCode called with agentIndex=\(agentIndex), message='\(message)'")

            // Track spawn time for this agent
            agentSpawnTimes[agentIndex] = Date()

            // Send message to Claude Code for this specific agent
            let sent = processManager.send(message: message, agentIndex: agentIndex)
            if sent {
                print("[Coordinator] Message sent to Claude Code for agent \(agentIndex)")
            } else {
                print("[Coordinator] Failed to send message to Claude Code for agent \(agentIndex)")
            }
        }

        /// Reset session tracking for a specific agent
        func resetAgentSession(agentIndex: Int) {
            // Remove session mappings for this agent
            sessionToAgentMap = sessionToAgentMap.filter { $0.value != agentIndex }
            agentSpawnTimes.removeValue(forKey: agentIndex)
            print("[WebView] Session tracking reset for agent \(agentIndex)")
        }

        /// Reset all session tracking
        func resetAllSessions() {
            sessionToAgentMap.removeAll()
            agentSpawnTimes.removeAll()
            print("[WebView] All session tracking reset")
        }
    }
}
