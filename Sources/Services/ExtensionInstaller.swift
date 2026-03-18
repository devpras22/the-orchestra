import AppKit
import Foundation

/// Manages VS Code/Cursor extension installation for IDE terminal switching
enum ExtensionInstaller {

    // MARK: - Constants

    private static let extensionId = "masko.masko-terminal-focus"

    /// Supported IDEs: (bundleId, CLI command, URI scheme, common CLI paths)
    private static let ideConfigs: [(bundleId: String, command: String, scheme: String, paths: [String])] = [
        (
            "com.todesktop.230313mzl4w4u92",
            "cursor",
            "cursor",
            [
                "/usr/local/bin/cursor",
                "/Applications/Cursor.app/Contents/Resources/app/bin/cursor",
            ]
        ),
        (
            "com.microsoft.VSCode",
            "code",
            "vscode",
            [
                "/usr/local/bin/code",
                "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            ]
        ),
        (
            "com.microsoft.VSCodeInsiders",
            "code-insiders",
            "vscode-insiders",
            [
                "/usr/local/bin/code-insiders",
                "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code-insiders",
            ]
        ),
        (
            "com.exafunction.windsurf",
            "windsurf",
            "windsurf",
            [
                "/usr/local/bin/windsurf",
                "/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf",
            ]
        ),
        (
            "com.google.antigravity",
            "antigravity",
            "antigravity",
            [
                "/usr/local/bin/antigravity",
                "/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity",
            ]
        ),
    ]

    // MARK: - IDE Status

    struct IDEStatus: Identifiable {
        let name: String
        let command: String
        let isDetected: Bool
        let isInstalled: Bool
        var id: String { command }
    }

    /// Returns per-IDE detection and installation status for all supported IDEs.
    static func allIDEStatuses() -> [IDEStatus] {
        ideConfigs.map { ide in
            let cliPath = resolveCommand(ide)
            let detected = cliPath != nil
            let installed = detected && extensionInstalled(cliPath: cliPath!)
            return IDEStatus(
                name: ideName(for: ide.command),
                command: ide.command,
                isDetected: detected,
                isInstalled: installed
            )
        }
    }

    // MARK: - Public API

    /// Bundled extension version — bump this when updating the VSIX
    static let bundledVersion = "1.0.0"

    /// Re-install the extension if the bundled version is newer than what was last installed.
    /// Called on app launch to ensure updates propagate automatically.
    static func upgradeIfNeeded() {
        let lastInstalled = UserDefaults.standard.string(forKey: "ideExtensionVersion") ?? "0"
        guard bundledVersion.compare(lastInstalled, options: .numeric) == .orderedDescending else { return }
        DispatchQueue.global(qos: .utility).async {
            do {
                try install()
                UserDefaults.standard.set(bundledVersion, forKey: "ideExtensionVersion")
            } catch {
                print("[masko-desktop] Extension upgrade failed: \(error)")
            }
        }
    }

    /// Check if the extension is installed in any detected IDE
    static func isInstalled() -> Bool {
        for ide in ideConfigs {
            if let path = resolveCommand(ide),
               extensionInstalled(cliPath: path) {
                return true
            }
        }
        return false
    }

    /// Detect which IDEs are available on the system
    static func availableIDEs() -> [(name: String, command: String)] {
        ideConfigs.compactMap { ide in
            resolveCommand(ide) != nil
                ? (name: ideName(for: ide.command), command: ide.command)
                : nil
        }
    }

    /// Install the extension into all detected IDEs
    static func install() throws {
        let vsixPath = bundledVSIXPath()
        guard FileManager.default.fileExists(atPath: vsixPath) else {
            throw ExtensionError.vsixNotFound
        }

        var installed = false
        for ide in ideConfigs {
            guard let cliPath = resolveCommand(ide) else { continue }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["--install-extension", vsixPath, "--force"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                installed = true
            }
        }

        if !installed {
            throw ExtensionError.noIDEFound
        }
    }

    /// Install the extension into a single IDE by command name
    static func install(command: String) throws {
        let vsixPath = bundledVSIXPath()
        guard FileManager.default.fileExists(atPath: vsixPath) else {
            throw ExtensionError.vsixNotFound
        }

        guard let ide = ideConfigs.first(where: { $0.command == command }),
              let cliPath = resolveCommand(ide) else {
            throw ExtensionError.noIDEFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["--install-extension", vsixPath, "--force"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExtensionError.noIDEFound
        }
    }

    /// Uninstall the extension from all detected IDEs
    static func uninstall() {
        for ide in ideConfigs {
            guard let cliPath = resolveCommand(ide) else { continue }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["--uninstall-extension", extensionId]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    /// Open a test URI so Cursor/VS Code shows the "allow this extension?" popup right away.
    static func triggerPermissionPrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Try each installed IDE's URI scheme
            for ide in ideConfigs {
                guard resolveCommand(ide) != nil else { continue }
                if let url = URL(string: "\(ide.scheme)://masko.masko-terminal-focus/setup") {
                    NSWorkspace.shared.open(url)
                    return
                }
            }
        }
    }

    /// Get the URI scheme for a given terminal PID's IDE bundle
    static func uriScheme(forBundleId bundleId: String?) -> String? {
        guard let bundleId else { return nil }
        return ideConfigs.first { $0.bundleId == bundleId }?.scheme
    }

    // MARK: - Private

    /// Find the CLI binary — try `which` first, then fall back to known paths
    private static func resolveCommand(
        _ ide: (bundleId: String, command: String, scheme: String, paths: [String])
    ) -> String? {
        // Try which first (works when the user has the CLI in their PATH)
        if let path = whichCommand(ide.command) {
            return path
        }
        // Fall back to common install locations
        for path in ide.paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func whichCommand(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }

    private static func extensionInstalled(cliPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["--list-extensions"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains(extensionId)
        } catch {
            return false
        }
    }

    private static func bundledVSIXPath() -> String {
        // Main app bundle
        if let path = Bundle.main.path(forResource: "masko-terminal-focus", ofType: "vsix") {
            return path
        }
        // Development fallback
        return NSHomeDirectory() + "/.orchestra-desktop/extensions/masko-terminal-focus.vsix"
    }

    private static func ideName(for command: String) -> String {
        switch command {
        case "cursor": return "Cursor"
        case "code": return "VS Code"
        case "code-insiders": return "VS Code Insiders"
        case "windsurf": return "Windsurf"
        case "antigravity": return "Antigravity"
        default: return command
        }
    }

    enum ExtensionError: LocalizedError {
        case vsixNotFound
        case noIDEFound

        var errorDescription: String? {
            switch self {
            case .vsixNotFound: return "Extension file not found in app bundle"
            case .noIDEFound: return "No supported IDE found (Cursor, VS Code, Windsurf)"
            }
        }
    }
}
