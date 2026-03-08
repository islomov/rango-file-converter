import SwiftUI
import UIKit

/// Centralized semantic color tokens with light/dark mode support.
/// Uses UIColor dynamic provider for iOS 16+ compatibility.
enum AppColors {

    // MARK: - Backgrounds

    /// Main screen background: light #F2F2F6, dark #1C1C1E
    static let background = adaptive(light: "F2F2F6", dark: "1C1C1E")

    /// Card/surface background: light white, dark #2C2C2E
    static let surface = adaptive(light: "FFFFFF", dark: "2C2C2E")

    /// Grouped/secondary background: light #F0F0F0, dark: #2C2C2E
    static let surfaceSecondary = adaptive(light: "F0F0F0", dark: "2C2C2E")

    // MARK: - Text

    /// Primary text: light #1D1D1D, dark #F5F5F5
    static let textPrimary = adaptive(light: "1D1D1D", dark: "F5F5F5")

    /// Secondary/muted text: light #888888, dark #8E8E93
    static let textSecondary = adaptive(light: "888888", dark: "8E8E93")

    /// Subtle/placeholder text: light #B0B0B8, dark #636366
    static let textTertiary = adaptive(light: "B0B0B8", dark: "636366")

    // MARK: - Accent

    /// Primary accent (orange): same in both modes
    static let accent = Color(hex: "F4800D")

    /// Light accent for gradients
    static let accentLight = Color(hex: "FFAD5B")

    // MARK: - Borders & Dividers

    /// Border/divider: light #E0E0E6, dark #3A3A3C
    static let border = adaptive(light: "E0E0E6", dark: "3A3A3C")

    /// Placeholder/ghost elements: light #E6E6EC, dark #3A3A3C
    static let placeholder = adaptive(light: "E6E6EC", dark: "3A3A3C")

    // MARK: - Shadows

    /// Shadow color: light #505050, dark #000000
    static let shadow = adaptive(light: "505050", dark: "000000")

    // MARK: - Tab Bar

    /// Tab bar background: light white, dark #303030 (with opacity in view)
    static let tabBarBackground = adaptive(light: "FFFFFF", dark: "303030")

    /// Unselected tab icon: light #1D1D1D, dark white
    static let tabIconDefault = adaptive(light: "1D1D1D", dark: "FFFFFF")

    // MARK: - Service Cards (brand colors, kept consistent)

    /// Image card background
    static let cardImage = adaptive(light: "1D1D1D", dark: "EEEEEE")

    /// Image card foreground
    static let cardImageForeground = adaptive(light: "FFFFFF", dark: "1D1D1D")

    /// Video card background
    static let cardVideo = adaptive(light: "FFFFFF", dark: "252525")

    /// Video card foreground
    static let cardVideoForeground = adaptive(light: "1D1D1D", dark: "F5F5F5")

    /// Audio card background (green)
    static let cardAudio = Color(hex: "A3E96C")

    /// Documents card background (purple)
    static let cardDocument = Color(hex: "BDA9F1")

    /// Dark foreground for audio/document cards
    static let cardDarkText = Color(hex: "1D1D1D")

    // MARK: - Buttons

    /// Gradient start for enabled action button
    static let buttonGradientStart = Color(hex: "FFA05C")
    /// Gradient end for enabled action button
    static let buttonGradientEnd = Color(hex: "EF731A")

    /// Gradient colors for disabled action button
    static let buttonDisabledStart = Color(hex: "FFD9B8")
    static let buttonDisabledMid = Color(hex: "F8C192")
    static let buttonDisabledEnd = Color(hex: "FFD9B8")

    // MARK: - Status Colors

    static let success = Color(hex: "2ECC71")
    static let error = Color(hex: "FF4D4D")
    static let info = Color(hex: "3498DB")

    // MARK: - Destructive

    static let destructive = Color(hex: "F21818")

    // MARK: - Helper

    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

// MARK: - UIColor hex initializer (private helper)

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: CGFloat
        switch hex.count {
        case 6:
            (r, g, b, a) = (
                CGFloat((int >> 16) & 0xFF) / 255,
                CGFloat((int >> 8) & 0xFF) / 255,
                CGFloat(int & 0xFF) / 255,
                1.0
            )
        case 8:
            (r, g, b, a) = (
                CGFloat((int >> 16) & 0xFF) / 255,
                CGFloat((int >> 8) & 0xFF) / 255,
                CGFloat(int & 0xFF) / 255,
                CGFloat((int >> 24) & 0xFF) / 255
            )
        default:
            (r, g, b, a) = (0, 0, 0, 1)
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
