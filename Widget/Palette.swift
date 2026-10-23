import SwiftUI

/// Colors from the approved design (dark, calm, one amber accent). Every
/// text color passes WCAG AA on `ground` and `surface`.
enum Palette {
    static let ground = Color(red: 0x12 / 255, green: 0x14 / 255, blue: 0x18 / 255)
    static let surface = Color(red: 0x1C / 255, green: 0x1F / 255, blue: 0x25 / 255)
    static let text = Color(red: 0xEC / 255, green: 0xE9 / 255, blue: 0xE2 / 255)
    /// The next line and secondary labels.
    static let dim = Color(red: 0xA3 / 255, green: 0xA6 / 255, blue: 0xAE / 255)
    static let faint = Color(red: 0x8A / 255, green: 0x8E / 255, blue: 0x97 / 255)
    /// Dashboard amber, used only for "where you are in the line".
    static let accent = Color(red: 0xE2 / 255, green: 0xB2 / 255, blue: 0x5A / 255)
    static let quietBar = Color(red: 0x5A / 255, green: 0x5E / 255, blue: 0x66 / 255)
}

extension Font {
    /// New York, Apple's built-in serif: lyrics read like verse.
    static func lyric(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
