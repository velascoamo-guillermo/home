// HomeTests/Theme/PaletteTests.swift
import Testing
import SwiftUI
import UIKit
@testable import Casita

@Suite("Palette") @MainActor struct PaletteTests {

    private static let fills: [(String, Color)] = [
        ("tasks", Palette.tasks), ("shopping", Palette.shopping),
        ("meals", Palette.meals), ("pets", Palette.pets),
        ("stock", Palette.stock), ("canvas", Palette.canvas),
        ("surface", Palette.surface),
    ]

    @Test("every fill resolves to different colors in light and dark")
    func dynamicFills() {
        for (name, color) in Self.fills {
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
}
