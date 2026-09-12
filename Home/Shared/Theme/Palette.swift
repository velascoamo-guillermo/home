import SwiftUI
import UIKit

nonisolated enum Palette {
    static let accent   = dynamic(light: 0xE8A090, dark: 0xF0B0A0)
    static let tasks    = dynamic(light: 0xD6E4F5, dark: 0x2B3A4F)
    static let shopping = dynamic(light: 0xD9EBD9, dark: 0x2C3F31)
    static let meals    = dynamic(light: 0xFBE3CF, dark: 0x4F3A2B)
    static let pets     = dynamic(light: 0xF6D9E0, dark: 0x4B2F38)
    static let stock    = dynamic(light: 0xE4DCF3, dark: 0x3A324F)
    static let canvas   = dynamic(light: 0xFAF8F5, dark: 0x121212)
    static let surface  = dynamic(light: 0xFFFFFF, dark: 0x1E1E1E)
    static let ink      = dynamic(light: 0x2A2A2A, dark: 0xF2F2F2)
    static let inkSecondary = dynamic(light: 0x2A2A2A, dark: 0xF2F2F2,
                                      lightAlpha: 0.55, darkAlpha: 0.60)

    static func uiColor(_ color: Color, style: UIUserInterfaceStyle) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private static func dynamic(light: UInt32, dark: UInt32,
                                lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? rgb(dark, alpha: darkAlpha)
                : rgb(light, alpha: lightAlpha)
        })
    }

    private static func rgb(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(red:   CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue:  CGFloat(hex & 0xFF) / 255,
                alpha: alpha)
    }
}
