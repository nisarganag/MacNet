import AppKit
import SwiftUI

enum Theme {
    static let panelSize = CGSize(width: 320, height: 444)
    static let cornerRadius: CGFloat = 26
    static let cardRadius: CGFloat = 18

    /// Download and upload are told apart by position and arrow as well as
    /// colour; blue against amber stays distinct for the common forms of
    /// colour blindness, and both hold contrast on light and dark glass.
    static let download = Color(light: 0x0A7FF5, dark: 0x5CB8FF)
    static let upload = Color(light: 0xE07000, dark: 0xFFAA45)

    /// A light veil under the glass: enough to keep 11 pt text legible over a
    /// busy wallpaper without smothering the refraction. Clear glass gets a
    /// thinner one because transparency is the point of choosing it.
    static func veil(_ style: GlassStyle, dark: Bool) -> Color {
        switch style {
        case .regular: dark ? .black.opacity(0.24) : .white.opacity(0.38)
        case .clear: dark ? .black.opacity(0.18) : .white.opacity(0.24)
        }
    }
}

extension Color {
    /// A colour that follows the system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}
