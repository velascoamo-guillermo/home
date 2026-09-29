import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

nonisolated enum Palette {
    static let accent       = dynamic(light: 0xF0607A, dark: 0xF58AA0)
    static let accentSoft   = dynamic(light: 0xE8A090, dark: 0xF0B0A0)
    static let onAccent     = dynamic(light: 0xFFFFFF, dark: 0x1B1522)
    static let tasks    = dynamic(light: 0xD6E4F5, dark: 0x2B3A4F)
    static let shopping = dynamic(light: 0xD9EBD9, dark: 0x2C3F31)
    static let meals    = dynamic(light: 0xFBE3CF, dark: 0x4F3A2B)
    static let pets     = dynamic(light: 0xF6D9E0, dark: 0x4B2F38)
    static let stock    = dynamic(light: 0xE4DCF3, dark: 0x3A324F)
    static let budget   = dynamic(light: 0xF7EDC4, dark: 0x4A4228)
    static let canvas   = dynamic(light: 0xFAF8F5, dark: 0x121212)
    static let canvasTop    = dynamic(light: 0xF3E6F6, dark: 0x1B1522)
    static let canvasMid    = dynamic(light: 0xFDE3E3, dark: 0x221820)
    static let canvasBottom = dynamic(light: 0xFFF8F3, dark: 0x121212)
    static let surface  = dynamic(light: 0xFFFFFF, dark: 0x1E1E1E, lightAlpha: 0.85, darkAlpha: 0.85)
    static let ink      = dynamic(light: 0x2A2A2A, dark: 0xF2F2F2)
    static let inkSecondary = dynamic(light: 0x2A2A2A, dark: 0xF2F2F2,
                                      lightAlpha: 0.55, darkAlpha: 0.60)

    /// sRGB red, green, blue, alpha of `color` in the light or dark appearance. Platform-neutral
    /// so the contrast suite runs unchanged on iOS and macOS.
    @MainActor
    static func components(_ color: Color, dark: Bool) -> SIMD4<Double> {
        #if os(macOS)
        components(NSColor(color), in: NSAppearance(named: dark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing())
        #else
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(Double(r), Double(g), Double(b), Double(a))
        #endif
    }

    #if os(macOS)
    @MainActor
    static func components(_ color: NSColor, in appearance: NSAppearance) -> SIMD4<Double> {
        var result = SIMD4<Double>(repeating: 0)
        appearance.performAsCurrentDrawingAppearance {
            guard let srgb = color.usingColorSpace(.sRGB) else { return }
            result = SIMD4(Double(srgb.redComponent), Double(srgb.greenComponent),
                           Double(srgb.blueComponent), Double(srgb.alphaComponent))
        }
        return result
    }
    #endif

    private static func dynamic(light: UInt32, dark: UInt32,
                                lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        #if os(macOS)
        // bestMatch folds the Increased Contrast appearances into their light/dark base.
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? rgb(dark, alpha: darkAlpha)
                : rgb(light, alpha: lightAlpha)
        })
        #else
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? rgb(dark, alpha: darkAlpha)
                : rgb(light, alpha: lightAlpha)
        })
        #endif
    }

    #if os(macOS)
    private static func rgb(_ hex: UInt32, alpha: CGFloat) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green:   CGFloat((hex >> 8) & 0xFF) / 255,
                blue:    CGFloat(hex & 0xFF) / 255,
                alpha:   alpha)
    }
    #else
    private static func rgb(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(red:   CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue:  CGFloat(hex & 0xFF) / 255,
                alpha: alpha)
    }
    #endif
}
