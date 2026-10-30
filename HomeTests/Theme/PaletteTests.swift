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

    private static let darkFeatures: [(String, Color)] = [
        ("tasks", Palette.tasks), ("shopping", Palette.shopping), ("meals", Palette.meals),
        ("pets", Palette.pets), ("stock", Palette.stock), ("budget", Palette.budget),
    ]

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

    @Test("dark feature fills share one perceptual lightness band")
    func darkFillLightnessBand() {
        let ls = Self.darkFeatures.map { Self.oklch(Palette.components($0.1, dark: true)).l }
        let spread = (ls.max() ?? 0) - (ls.min() ?? 0)
        #expect(spread <= 0.02, "dark fill OKLab L spread \(spread)")
        for (i, (name, _)) in Self.darkFeatures.enumerated() {
            #expect(ls[i] >= 0.28 && ls[i] <= 0.32, "\(name) OKLab L \(ls[i])")
        }
    }

    @Test("dark fills stay in the plum family: plum hue window or near-neutral, faint chroma")
    func darkPlumFamily() {
        let canvasHue = Self.oklch(Palette.components(Palette.canvasTop, dark: true)).h
        #expect(canvasHue >= 300 && canvasHue <= 340, "canvasTop hue \(canvasHue)")
        for (name, color) in Self.darkFeatures {
            let c = Self.oklch(Palette.components(color, dark: true))
            #expect(c.c <= 0.07, "\(name) chroma \(c.c) too strong")
            let inPlumWindow = c.h >= 280 && c.h <= 360
            #expect(inPlumWindow || c.c <= 0.025, "\(name) hue \(c.h) chroma \(c.c) outside plum family")
        }
    }

    @Test("dark meals is not brown or orange")
    func darkMealsNotBrown() {
        let m = Self.oklch(Palette.components(Palette.meals, dark: true))
        let brownish = m.h >= 20 && m.h <= 110 && m.c >= 0.03
        #expect(!brownish, "meals hue \(m.h) chroma \(m.c)")
    }

    @Test("dark feature fills stay distinguishable from each other")
    func darkFillsDistinguishable() {
        let labs = Self.darkFeatures.map { Self.oklab(Palette.components($0.1, dark: true)) }
        for i in labs.indices {
            for j in labs.indices where j > i {
                let d = Self.deltaE(labs[i], labs[j])
                #expect(d >= 0.03, "\(Self.darkFeatures[i].0) vs \(Self.darkFeatures[j].0) deltaE \(d)")
            }
        }
    }

    @Test("accent holds 4.5:1 on every dark feature fill")
    func darkAccentOnFills() {
        let accent = Palette.components(Palette.accent, dark: true)
        for (name, color) in Self.darkFeatures {
            let ratio = Self.contrastRatio(accent, Palette.components(color, dark: true))
            #expect(ratio >= 4.5, "\(name) ratio \(ratio)")
        }
    }

    @Test("inkSecondary is AA over every dark fill, surface composited over each canvas stop")
    func darkInkSecondary() {
        let ink2 = Palette.components(Palette.inkSecondary, dark: true)
        func check(_ name: String, _ bg: SIMD4<Double>) {
            let ratio = Self.contrastRatio(Self.composite(ink2, over: bg), bg)
            #expect(ratio >= 4.5, "\(name) ratio \(ratio)")
        }
        for (name, color) in Self.fills where name != "surface" {
            check(name, Palette.components(color, dark: true))
        }
        let surface = Palette.components(Palette.surface, dark: true)
        for (name, stop) in [("canvasTop", Palette.canvasTop), ("canvasMid", Palette.canvasMid),
                             ("canvasBottom", Palette.canvasBottom), ("canvas", Palette.canvas)] {
            check("surface over \(name)", Self.composite(surface, over: Palette.components(stop, dark: true)))
        }
    }

    @Test("light values are unchanged")
    func lightValuesPinned() {
        let expected: [(String, Color, UInt32)] = [
            ("tasks", Palette.tasks, 0xD6E4F5), ("shopping", Palette.shopping, 0xD9EBD9),
            ("meals", Palette.meals, 0xFBE3CF), ("pets", Palette.pets, 0xF6D9E0),
            ("stock", Palette.stock, 0xE4DCF3), ("budget", Palette.budget, 0xF7EDC4),
            ("accent", Palette.accent, 0xF0607A), ("accentSoft", Palette.accentSoft, 0xE8A090),
            ("canvasTop", Palette.canvasTop, 0xF3E6F6), ("canvasMid", Palette.canvasMid, 0xFDE3E3),
            ("canvasBottom", Palette.canvasBottom, 0xFFF8F3), ("canvas", Palette.canvas, 0xFAF8F5),
            ("surface", Palette.surface, 0xFFFFFF), ("ink", Palette.ink, 0x2A2A2A),
            ("inkSecondary", Palette.inkSecondary, 0x2A2A2A), ("onAccent", Palette.onAccent, 0xFFFFFF),
        ]
        let alphas: [(String, Color, Double)] = [
            ("surface", Palette.surface, 0.85), ("inkSecondary", Palette.inkSecondary, 0.55),
        ]
        for (name, color, alpha) in alphas {
            #expect(abs(Palette.components(color, dark: false).w - alpha) < 0.003, "\(name) light alpha changed")
        }
        for (name, color, hex) in expected {
            let c = Palette.components(color, dark: false)
            #expect(abs(c.x - Double((hex >> 16) & 0xFF) / 255) < 0.003
                    && abs(c.y - Double((hex >> 8) & 0xFF) / 255) < 0.003
                    && abs(c.z - Double(hex & 0xFF) / 255) < 0.003, "\(name) light changed")
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

    private static func oklab(_ c: SIMD4<Double>) -> SIMD3<Double> {
        func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let r = lin(c.x), g = lin(c.y), b = lin(c.z)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return SIMD3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    /// OKLCH lightness, chroma and hue in degrees [0, 360).
    private static func oklch(_ c: SIMD4<Double>) -> (l: Double, c: Double, h: Double) {
        let lab = oklab(c)
        let hue = atan2(lab.z, lab.y) * 180 / .pi
        return (lab.x, (lab.y * lab.y + lab.z * lab.z).squareRoot(), hue < 0 ? hue + 360 : hue)
    }

    private static func deltaE(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }

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
