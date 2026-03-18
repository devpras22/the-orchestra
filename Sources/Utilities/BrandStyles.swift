import SwiftUI

// MARK: - Card

struct BrandCard: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Constants.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .shadow(
                color: isHovered ? Constants.cardHoverShadowColor : Constants.cardShadowColor,
                radius: isHovered ? Constants.cardHoverShadowRadius : Constants.cardShadowRadius,
                x: 0,
                y: isHovered ? Constants.cardHoverShadowY : Constants.cardShadowY
            )
    }
}

// MARK: - Buttons

struct BrandPrimaryButton: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Constants.heading(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isDisabled ? Constants.orangePrimary.opacity(0.4) : Constants.orangePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .shadow(
                color: isDisabled ? Color.clear : Constants.orangeShadow,
                radius: 0,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct BrandSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Constants.heading(size: 13, weight: .medium))
            .foregroundColor(Constants.orangePrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Constants.orangePrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct BrandGhostButton: ButtonStyle {
    var color: Color = Constants.textMuted

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Constants.body(size: 13, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
