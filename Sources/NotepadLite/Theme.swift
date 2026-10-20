import AppKit

enum TokenKind: Int {
    case keyword, type, string, comment, number, meta, tag, attribute

    var color: NSColor { Theme.tokenColors[rawValue] }
}

enum Theme {
    static func hex(_ v: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255,
                alpha: alpha)
    }

    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> NSColor {
        dynamic(light: hex(light), dark: hex(dark))
    }

    /// Indexed by TokenKind.rawValue.
    static let tokenColors: [NSColor] = [
        dynamic(0x0000D0, 0x569CD6), // keyword
        dynamic(0x267F99, 0x4EC9B0), // type
        dynamic(0xA31515, 0xCE9178), // string
        dynamic(0x008000, 0x6A9955), // comment
        dynamic(0x098658, 0xB5CEA8), // number
        dynamic(0xAF00DB, 0xC586C0), // meta / preprocessor
        dynamic(0x800000, 0x569CD6), // tag
        dynamic(0xE50000, 0x9CDCFE), // attribute
    ]

    static let currentLine = dynamic(light: hex(0x3060FF, alpha: 0.07), dark: hex(0xFFFFFF, alpha: 0.06))
    static let gutterBackground = dynamic(light: hex(0xF4F4F4), dark: hex(0x232323))
    static let gutterSeparator = dynamic(light: hex(0xDDDDDD), dark: hex(0x3A3A3A))
    static let gutterText = dynamic(light: hex(0x9A9A9A), dark: hex(0x6E6E6E))
    static let gutterCurrentText = dynamic(light: hex(0x333333), dark: hex(0xD0D0D0))
}
