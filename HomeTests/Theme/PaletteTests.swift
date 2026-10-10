import Testing
import SwiftUI
#if os(macOS)
import AppKit
#endif
@testable import Casita

@Suite("Palette") @MainActor struct PaletteTests {

    // Backgrounds `ink` is actually painted on — feeds both `dynamicFills()` and `contrast()`.
    private static let fills: [(String, Color)] = [
        ("tasks", Palette.tasks), ("shopping", Palette.shopping),
        ("meals", Palette.meals), ("pets", Palette.pets),
        ("stock", Palette.stock), ("budget", Palette.budget), ("canvas", Palette.canvas),
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
            let light = Palette.components(color, dark: false)
            let dark = Palette.components(color, dark: true)
            #expect(light != dark, "\(name) should be dynamic")
        }
    }

    @Test("ink is readable on every fill in both schemes")
    func contrast() {
        for dark in [false, true] {
            let ink = Palette.components(Palette.ink, dark: dark)
            for (name, color) in Self.fills {
                let ratio = Self.contrastRatio(ink, Palette.components(color, dark: dark))
                #expect(ratio >= 4.5, "\(name) \(dark ? "dark" : "light") ratio \(ratio)")
            }
        }
    }

    @Test("accent is the fixed coral F0607A in light")
    func accent() {
        let light = Palette.components(Palette.accent, dark: false)
        #expect(abs(light.x - 0xF0 / 255) < 0.01)
        #expect(abs(light.y - 0x60 / 255) < 0.01)
        #expect(abs(light.z - 0x7A / 255) < 0.01)
    }

    @Test("feature fills are distinct from each other in both schemes")
    func distinctFills() {
        let features: [Color] = [Palette.tasks, Palette.shopping, Palette.meals, Palette.pets, Palette.stock, Palette.budget]
        for dark in [false, true] {
            let resolved = features.map { Palette.components($0, dark: dark) }
            #expect(Set(resolved).count == features.count, "\(dark ? "dark" : "light")")
        }
    }

    @Test("ink on translucent surface stays readable over every canvas stop")
    func surfaceOverCanvasContrast() {
        let canvasStops: [(String, Color)] = [
            ("canvasTop", Palette.canvasTop), ("canvasMid", Palette.canvasMid),
            ("canvasBottom", Palette.canvasBottom),
        ]
        for dark in [false, true] {
            let ink = Palette.components(Palette.ink, dark: dark)
            let surface = Palette.components(Palette.surface, dark: dark)
            for (name, canvas) in canvasStops {
                let blended = Self.composite(surface, over: Palette.components(canvas, dark: dark))
                let ratio = Self.contrastRatio(ink, blended)
                #expect(ratio >= 4.5, "\(name) \(dark ? "dark" : "light") ratio \(ratio)")
            }
        }
    }

    @Test("onAccent meets 3:1 against accent in both schemes")
    func onAccentContrast() {
        for dark in [false, true] {
            let ratio = Self.contrastRatio(Palette.components(Palette.onAccent, dark: dark),
                                           Palette.components(Palette.accent, dark: dark))
            #expect(ratio >= 3.0, "\(dark ? "dark" : "light") ratio \(ratio)")
        }
    }

    @Test("accent is distinct from accentSoft in both schemes")
    func accentDistinctFromSoft() {
        for dark in [false, true] {
            #expect(Palette.components(Palette.accent, dark: dark)
                    != Palette.components(Palette.accentSoft, dark: dark), "\(dark ? "dark" : "light")")
        }
    }

    #if os(macOS)
    @Test("Increased Contrast appearances resolve to the same passing light and dark values")
    func increasedContrastAppearances() throws {
        let cases: [(NSAppearance.Name, Bool)] = [
            (.accessibilityHighContrastAqua, false), (.accessibilityHighContrastDarkAqua, true),
        ]
        for (name, dark) in cases {
            let appearance = try #require(NSAppearance(named: name))
            for (fill, color) in Self.fills + Self.nonTextFills + [("ink", Palette.ink)] {
                #expect(Palette.components(NSColor(color), in: appearance) == Palette.components(color, dark: dark),
                        "\(fill) under \(name.rawValue)")
            }
        }
    }
    #endif

    private static func luminance(_ c: SIMD4<Double>) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.x) + 0.7152 * lin(c.y) + 0.0722 * lin(c.z)
    }

    private static func contrastRatio(_ a: SIMD4<Double>, _ b: SIMD4<Double>) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Straight source-over alpha blend of `top` onto opaque `bottom` — `luminance` is alpha-blind,
    /// so callers that care about a translucent surface must blend before measuring contrast.
    private static func composite(_ top: SIMD4<Double>, over bottom: SIMD4<Double>) -> SIMD4<Double> {
        let outA = top.w + bottom.w * (1 - top.w)
        func blend(_ t: Double, _ b: Double) -> Double {
            guard outA > 0 else { return 0 }
            return (t * top.w + b * bottom.w * (1 - top.w)) / outA
        }
        return SIMD4(blend(top.x, bottom.x), blend(top.y, bottom.y), blend(top.z, bottom.z), outA)
    }
}
