import SwiftUI

enum Constants {
    // The Orchestra - Kid AI Agent Visualizer
    static let appVersion = "0.1.0"
    static let githubRepoURL = "https://github.com/devpras22/the-orchestra"

    // Local hook server - Port 49153 (Masko uses 49152)
    static let defaultServerPort: UInt16 = 49153
    static var serverPort: UInt16 {
        let stored = UserDefaults.standard.integer(forKey: "orchestraServerPort")
        return stored > 0 ? UInt16(stored) : defaultServerPort
    }
    static func setServerPort(_ port: UInt16) {
        UserDefaults.standard.set(Int(port), forKey: "orchestraServerPort")
    }

    // Brand colors - Orchestra theme (warm, kid-friendly)
    static let orangePrimary = Color(red: 249/255, green: 93/255, blue: 2/255)     // #f95d02
    static let orangeHover = Color(red: 251/255, green: 121/255, blue: 16/255)     // #fb7910
    static let purplePrimary = Color(red: 138/255, green: 43/255, blue: 226/255)   // #8a2be2
    static let stageBackground = Color(red: 30/255, green: 20/255, blue: 50/255)   // Dark stage
    static let curtainRed = Color(red: 139/255, green: 0/255, blue: 0/255)         // #8b0000
    static let goldAccent = Color(red: 255/255, green: 215/255, blue: 0/255)       // #ffd700
    static let textPrimary = Color.white
    static let textMuted = Color.white.opacity(0.65)
    static let surfaceWhite = Color.white
    static let border = Color.white.opacity(0.12)
    static let borderHover = Color.white.opacity(0.20)

    // MARK: - Typography

    /// Fredoka — headings, buttons, display text
    static func heading(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Fredoka", size: size).weight(weight)
    }

    /// Rubik — body text, labels, metadata
    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Rubik", size: size).weight(weight)
    }

    // MARK: - Layout

    static let cornerRadius: CGFloat = 14
    static let cornerRadiusSmall: CGFloat = 10

    // MARK: - Shadows

    /// Default card shadow
    static let cardShadowColor = Color.black.opacity(0.3)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4

    /// Spotlight glow
    static let spotlightGlow = Color(red: 255/255, green: 255/255, blue: 200/255).opacity(0.3)

    // MARK: - Hover Shadows (for BrandStyles)

    static let cardHoverShadowColor = Color.black.opacity(0.5)
    static let cardHoverShadowRadius: CGFloat = 16
    static let cardHoverShadowY: CGFloat = 8

    /// Orange button shadow
    static let orangeShadow = Color.orange.opacity(0.4)

    // MARK: - External URLs

    static let maskoBaseURL = "https://masko.app"
}
