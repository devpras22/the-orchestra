import SwiftUI
import AppKit
import CoreText

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Regular app with dock icon
        NSApp.setActivationPolicy(.regular)
        registerBundledFonts()
    }

    private func registerBundledFonts() {
        let fontNames = [
            "Fredoka-Regular", "Fredoka-Medium", "Fredoka-SemiBold", "Fredoka-Bold",
            "Rubik-Regular", "Rubik-Medium", "Rubik-SemiBold"
        ]
        for name in fontNames {
            // Try main bundle first
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        // Terminal will be spawned lazily when user interacts with an agent
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Close all tmux sessions when app quits
        ClaudeCodeProcessManager.shared.stopAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    /// Show the main dashboard window (called by GlobalHotkeyManager)
    static func showDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct TheOrchestraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            OrchestraStageView()
                .environment(appStore)
                .frame(minWidth: 1000, minHeight: 700)
                .preferredColorScheme(.dark)
                .task {
                    guard !appStore.isRunning else { return }
                    await appStore.start()
                }
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.hiddenTitleBar)

        // Settings window
        Settings {
            SettingsView()
                .environment(appStore)
        }
    }
}
