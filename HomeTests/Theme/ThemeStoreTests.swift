import Testing
import SwiftUI
@testable import Home

@MainActor
struct ThemeStoreTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "ThemeStoreTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func defaultsWhenEmpty() {
        let store = ThemeStore(defaults: freshDefaults())
        #expect(store.appearance == .system)
        #expect(store.tintHex == ThemeStore.defaultTintHex)
        #expect(store.colorScheme == nil)
    }

    @Test func persistsAcrossInstances() {
        let d = freshDefaults()
        let store = ThemeStore(defaults: d)
        store.appearance = .dark
        store.tintHex = "0A84FF"

        let reloaded = ThemeStore(defaults: d)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.tintHex == "0A84FF")
    }

    @Test func tintFallsBackOnBadHex() {
        let store = ThemeStore(defaults: freshDefaults())
        store.tintHex = "garbage"
        #expect(store.tint == Color(hex: ThemeStore.defaultTintHex))
    }

    @Test func presetsIncludeDefaultFirst() {
        #expect(ThemeStore.presets.first == ThemeStore.defaultTintHex)
    }
}
