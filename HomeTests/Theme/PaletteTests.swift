import Testing
import SwiftUI
import UIKit
@testable import Casita

@Suite("Palette") @MainActor struct PaletteTests {

    // Backgrounds `ink` is actually painted on — feeds both `dynamicFills()` and `contrast()`.
    private static let fills: [(String, Color)] = [
        ("tasks", Palette.tasks), ("shopping", Palette.shopping),
        ("meals", Palette.meals), ("pets", Palette.pets),
        ("stock", Palette.stock), ("canvas", Palette.canvas),
        ("surface", Palette.surface),
        ("canvasTop", Palette.canvasTop), ("canvasMid", Palette.canvasMid),
        ("canvasBottom", Palette.canvasBottom),
    ]

    // Accent-family fills that pair with `onAccent`, not `ink` — checked for dynamism only;
    // their contrast is covered by `onAccentContrast()` / `surfaceOverCanvasContrast()`.
    private static let nonTextFills: [(String, Color)] = [
        ("accentSoft", Palette.accentSoft), ("onAccent", Palette.onAccent),
    ]

    @Test("every fill resolves to different colors in light and dark")
    func dynamicFills() {
        for (name, color) in Self.fills + Self.nonTextFills {
            let light = Palette.uiColor(color, style: .light)
            let dark = Palette.uiColor(color, style: .dark)
            #expect(light != dark, "\(name) should be dynamic")
        }
    }

    @Test("ink is readable on every fill in both schemes")
    func contrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let ink = Palette.uiColor(Palette.ink, style: style)
            for (name, color) in Self.fills {
                let fill = Palette.uiColor(color, style: style)
                let ratio = Self.contrastRatio(ink, fill)
                #expect(ratio >= 4.5, "\(name) \(style == .dark ? "dark" : "light") ratio \(ratio)")
            }
        }
    }

    @Test("accent is a fixed coral, not the system blue")
    func accent() {
        let light = Palette.uiColor(Palette.accent, style: .light)
        #expect(light != UIColor.systemBlue.resolvedColor(with: .init(userInterfaceStyle: .light)))
    }

    @Test("feature fills are distinct from each other in both schemes")
    func distinctFills() {
        let features: [Color] = [Palette.tasks, Palette.shopping, Palette.meals, Palette.pets, Palette.stock]
        for style in [UIUserInterfaceStyle.light, .dark] {
            let resolved = features.map { Palette.uiColor($0, style: style) }
            #expect(Set(resolved).count == features.count, "\(style == .dark ? "dark" : "light")")
        }
    }

    @Test("ink on translucent surface stays readable over every canvas stop")
    func surfaceOverCanvasContrast() {
        let canvasStops: [(String, Color)] = [
            ("canvasTop", Palette.canvasTop), ("canvasMid", Palette.canvasMid),
            ("canvasBottom", Palette.canvasBottom),
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            let ink = Palette.uiColor(Palette.ink, style: style)
            let surface = Palette.uiColor(Palette.surface, style: style)
            for (name, canvas) in canvasStops {
                let bottom = Palette.uiColor(canvas, style: style)
                let blended = Self.composite(surface, over: bottom)
                let ratio = Self.contrastRatio(ink, blended)
                #expect(ratio >= 4.5, "\(name) \(style == .dark ? "dark" : "light") ratio \(ratio)")
            }
        }
    }

    @Test("onAccent meets 3:1 against accent in both schemes")
    func onAccentContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let onAccent = Palette.uiColor(Palette.onAccent, style: style)
            let accent = Palette.uiColor(Palette.accent, style: style)
            let ratio = Self.contrastRatio(onAccent, accent)
            #expect(ratio >= 3.0, "\(style == .dark ? "dark" : "light") ratio \(ratio)")
        }
    }

    @Test("accent is distinct from accentSoft in both schemes")
    func accentDistinctFromSoft() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let accent = Palette.uiColor(Palette.accent, style: style)
            let accentSoft = Palette.uiColor(Palette.accentSoft, style: style)
            #expect(accent != accentSoft, "\(style == .dark ? "dark" : "light")")
        }
    }

    private static func luminance(_ c: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: nil)
        func lin(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private static func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Straight source-over alpha blend of `top` onto opaque `bottom` — `luminance` is alpha-blind,
    /// so callers that care about a translucent surface must blend before measuring contrast.
    private static func composite(_ top: UIColor, over bottom: UIColor) -> UIColor {
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        bottom.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let outA = ta + ba * (1 - ta)
        func blend(_ t: CGFloat, _ b: CGFloat) -> CGFloat {
            guard outA > 0 else { return 0 }
            return (t * ta + b * ba * (1 - ta)) / outA
        }
        return UIColor(red: blend(tr, br), green: blend(tg, bg), blue: blend(tb, bb), alpha: outA)
    }
}
