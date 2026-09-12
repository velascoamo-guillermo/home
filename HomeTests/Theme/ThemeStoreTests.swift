import Testing
import SwiftUI
@testable import Casita

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
        #expect(store.colorScheme == nil)
    }

    @Test func persistsAppearanceAcrossInstances() {
        let d = freshDefaults()
        let store = ThemeStore(defaults: d)
        store.appearance = .dark

        let reloaded = ThemeStore(defaults: d)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.colorScheme == .dark)
    }

    @Test func ignoresLegacyTintKey() {
        let d = freshDefaults()
        d.set("0A84FF", forKey: "theme.tintHex")
        let store = ThemeStore(defaults: d)
        #expect(store.appearance == .system)
    }
}
