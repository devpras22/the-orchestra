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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Permission Popup

struct PermissionPopupView: View {
    let permission: PendingPermission
    @Environment(AppStore.self) var appStore

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Text("🎭")
                .font(.system(size: 48))

            // Title
            Text("Claude needs permission")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)

            // What tool
            VStack(spacing: 8) {
                Text(permission.toolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.orange)

                Text(permission.toolInputPreview)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(.horizontal, 20)

            // Buttons
            HStack(spacing: 20) {
                Button {
                    appStore.pendingPermissionStore.resolve(id: permission.id, decision: .allow)
                } label: {
                    Text("Yes, do it!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    appStore.pendingPermissionStore.resolve(id: permission.id, decision: .deny)
                } label: {
                    Text("No, stop")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.15, green: 0.08, blue: 0.25))
                .shadow(color: .black.opacity(0.5), radius: 30)
        )
    }
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
