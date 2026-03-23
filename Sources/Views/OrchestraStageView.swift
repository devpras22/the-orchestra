import SwiftUI

// MARK: - Session State

enum SessionState: String {
    case working
    case thinking
    case waiting
    case idle
    case error
}

extension AgentSession {
    var displayState: SessionState {
        if isCompacting { return .thinking }
        switch phase {
        case .running: return .working
        case .compacting: return .thinking
        case .idle: return .idle
        }
    }
}

// MARK: - Main View

struct OrchestraStageView: View {
    @Environment(AppStore.self) var appStore

    var body: some View {
        ZStack {
            // 3D Stage
            OrchestraWebView()

            // Permission popup (only when needed)
            if let permission = appStore.pendingPermissionStore.pending.first {
                PermissionPopupView(permission: permission)
            }

            // Inter-agent message popup (only when needed)
            if let message = appStore.interAgentMessageStore.pending.first {
                InterAgentMessagePopupView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Permission Popup (Kid-Friendly White Theme)

struct PermissionPopupView: View {
    let permission: PendingPermission
    @Environment(AppStore.self) var appStore

    // Kid-friendly colors matching the app's white theme
    private let accentPurple = Color(red: 139/255, green: 92/255, blue: 246/255) // #8B5CF6
    private let textDark = Color(red: 35/255, green: 17/255, blue: 60/255)
    private let textMuted = Color(red: 35/255, green: 17/255, blue: 60/255).opacity(0.55)
    private let codeBg = Color(red: 250/255, green: 249/255, blue: 247/255)

    // Kid-friendly icon based on tool type
    private var iconEmoji: String {
        let tool = permission.toolName.lowercased()
        if tool.contains("read") || tool.contains("file") { return "📖" }
        if tool.contains("write") || tool.contains("edit") { return "✏️" }
        if tool.contains("bash") || tool.contains("run") { return "🚀" }
        if tool.contains("web") { return "🌐" }
        return "✨"
    }

    // Kid-friendly title
    private var friendlyTitle: String {
        let tool = permission.toolName.lowercased()
        if tool.contains("read") { return "Read a file?" }
        if tool.contains("write") || tool.contains("edit") { return "Make a change?" }
        if tool.contains("bash") { return "Run a command?" }
        return "Can I do this?"
    }

    // Check if we have "always allow" suggestions
    private var hasSuggestions: Bool {
        !permission.permissionSuggestions.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Text(iconEmoji)
                .font(.system(size: 44))

            // Title
            Text(friendlyTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textDark)

            // Tool name badge
            Text(permission.toolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentPurple)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentPurple.opacity(0.1))
                .cornerRadius(20)

            // What it wants to do
            Text(permission.toolInputPreview)
                .font(.system(size: 13))
                .foregroundColor(textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(codeBg)
                .cornerRadius(10)

            // Main buttons - Allow / Deny
            HStack(spacing: 10) {
                // Deny button (secondary)
                Button {
                    appStore.pendingPermissionStore.resolve(id: permission.id, decision: .deny)
                } label: {
                    Text("No thanks")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(textMuted.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                // Allow button (primary)
                Button {
                    appStore.pendingPermissionStore.resolve(id: permission.id, decision: .allow)
                } label: {
                    Text("Sure! ✓")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(accentPurple)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Always-allow suggestions (third button option)
            if hasSuggestions {
                Divider()
                    .padding(.vertical, 4)

                ForEach(permission.permissionSuggestions) { suggestion in
                    Button {
                        appStore.pendingPermissionStore.resolveWithPermissions(id: permission.id, suggestions: [suggestion])
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(accentPurple.opacity(0.8))
                            Text(suggestion.displayLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(accentPurple.opacity(0.06))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 6)
        )
    }
}

// MARK: - Inter-Agent Message Popup

struct InterAgentMessagePopupView: View {
    let message: InterAgentMessage
    @Environment(AppStore.self) var appStore

    private let accentAmber = Color(red: 245/255, green: 158/255, blue: 11/255) // #F59E0B
    private let textDark = Color(red: 35/255, green: 17/255, blue: 60/255)
    private let textMuted = Color(red: 35/255, green: 17/255, blue: 60/255).opacity(0.55)

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Text("💬")
                .font(.system(size: 44))

            // Title
            Text("Message from \(message.fromAgentName)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textDark)

            // To badge
            Text("to \(message.toAgentName)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentAmber)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentAmber.opacity(0.1))
                .cornerRadius(20)

            // Message preview
            Text(message.message)
                .font(.system(size: 13))
                .foregroundColor(textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(red: 250/255, green: 249/255, blue: 247/255))
                .cornerRadius(10)

            // Buttons
            HStack(spacing: 10) {
                // Ignore button (secondary)
                Button {
                    appStore.interAgentMessageStore.dismiss(id: message.id)
                } label: {
                    Text("Ignore")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(textMuted.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                // Open Chat button (primary)
                Button {
                    openAgentChat(agentIndex: message.toAgentIndex)
                    appStore.interAgentMessageStore.dismiss(id: message.id)
                } label: {
                    Text("Open Chat ✓")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(accentAmber)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 6)
        )
    }

    private func openAgentChat(agentIndex: Int) {
        let js = """
        (function() {
          if (window.startChatWithAgent) {
            window.startChatWithAgent(\(agentIndex));
          }
        })();
        """
        // Evaluate via the WebView — post to notification center since we don't have direct webView access
        NotificationCenter.default.post(name: .evaluateJavaScript, object: js)
    }
}

// Notification name for JS evaluation from views
extension Notification.Name {
    static let evaluateJavaScript = Notification.Name("evaluateJavaScript")
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🎭 The Orchestra")
                .font(.system(size: 24, weight: .bold))

            Text("Settings")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
