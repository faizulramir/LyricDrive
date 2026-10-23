import SwiftUI

/// The approved design's colors, in light and dark. The app follows the
/// phone's appearance setting; every text color passes WCAG AA on `ground`.
enum AppColor {
    static let ground = adaptive(light: 0xF2F1ED, dark: 0x121418)
    static let surface = adaptive(light: 0xE6E4DE, dark: 0x1C1F25)
    static let text = adaptive(light: 0x1A1C21, dark: 0xECE9E2)
    /// The next line and supporting copy.
    static let dim = adaptive(light: 0x5C606A, dark: 0xA3A6AE)
    /// Lines already sung, lines further ahead, footnotes.
    static let faint = adaptive(light: 0x62666F, dark: 0x8A8E97)
    /// Dashboard amber: progress through the line and the one main action.
    static let accent = adaptive(light: 0x8A5F12, dark: 0xE2B25A)
    /// Text on an accent button.
    static let onAccent = adaptive(light: 0xF2F1ED, dark: 0x121418)
    static let track = adaptive(light: 0xDAD8D1, dark: 0x2A2D33)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// New York, Apple's built-in serif: lyrics read like verse.
    static func lyric(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// The design's 52pt buttons: one accent action per screen at most.
struct ActionButtonStyle: ButtonStyle {
    enum Kind { case accent, surface, quiet }
    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            // Visible press feedback for touch (no hover on a phone).
            .opacity(configuration.isPressed ? 0.7 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .accent: AppColor.onAccent
        case .surface: AppColor.text
        case .quiet: AppColor.dim
        }
    }

    private var background: Color {
        switch kind {
        case .accent: AppColor.accent
        case .surface: AppColor.surface
        case .quiet: .clear
        }
    }
}

extension ButtonStyle where Self == ActionButtonStyle {
    static func action(_ kind: ActionButtonStyle.Kind) -> ActionButtonStyle { .init(kind: kind) }
}
