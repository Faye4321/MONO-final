import SwiftUI
import UIKit

// MARK: - Homepage Colors

enum BrandColor {
    static let archiveIvory = Color(hex: 0xF3F0E9)
    static let inkBlack = Color(hex: 0x171714)
    static let collectedRed = Color(hex: 0xB84631)
    static let paperTan = Color(hex: 0xD5B99C)
    static let catalogGray = Color(hex: 0x706B63)
    static let heroStone = Color(hex: 0xD9D1C3)
    static let softCard = Color(hex: 0xE9E4DA)
    static let olive = Color(hex: 0x727B70)
}

// This does not conflict with the existing Color(hex: String)
// because this version accepts a UInt.
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Homepage Typography

private enum MonoFontName {
    // If the licensed Natom Pro files are added later,
    // these names will be used automatically.
    // Until then, the system rounded font is used.
    static let title = "NatomPro-TitleMedium"
    static let medium = "NatomPro-Medium"
    static let regular = "NatomPro-Regular"
}

private struct MonoFontModifier: ViewModifier {
    let customName: String
    let size: CGFloat
    let relativeTo: Font.TextStyle
    let fallbackWeight: Font.Weight
    let tracking: CGFloat

    func body(content: Content) -> some View {
        content
            .font(resolvedFont)
            .tracking(tracking)
    }

    private var resolvedFont: Font {
        if UIFont(name: customName, size: size) != nil {
            return .custom(
                customName,
                size: size,
                relativeTo: relativeTo
            )
        }

        return .system(
            size: size,
            weight: fallbackWeight,
            design: .rounded
        )
    }
}

extension View {
    func monoTitle(
        _ size: CGFloat,
        tracking: CGFloat = -0.4
    ) -> some View {
        modifier(
            MonoFontModifier(
                customName: MonoFontName.title,
                size: size,
                relativeTo: .title,
                fallbackWeight: .medium,
                tracking: tracking
            )
        )
    }

    func monoHeading(
        _ size: CGFloat,
        tracking: CGFloat = -0.2
    ) -> some View {
        modifier(
            MonoFontModifier(
                customName: MonoFontName.medium,
                size: size,
                relativeTo: .headline,
                fallbackWeight: .medium,
                tracking: tracking
            )
        )
    }

    func monoBody(
        _ size: CGFloat,
        tracking: CGFloat = 0
    ) -> some View {
        modifier(
            MonoFontModifier(
                customName: MonoFontName.regular,
                size: size,
                relativeTo: .body,
                fallbackWeight: .regular,
                tracking: tracking
            )
        )
    }

    func monoLabel(
        _ size: CGFloat = 11,
        tracking: CGFloat = 0.8
    ) -> some View {
        modifier(
            MonoFontModifier(
                customName: MonoFontName.medium,
                size: size,
                relativeTo: .caption,
                fallbackWeight: .medium,
                tracking: tracking
            )
        )
    }
}

// MARK: - Haptics

enum Haptics {
    /// Settings ▸ Haptics. On unless the user turns it off.
    static let settingKey = "settings.hapticsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator()
            .selectionChanged()
    }

    static func light() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)
    }
}
