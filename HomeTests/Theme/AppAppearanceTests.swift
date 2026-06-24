import Testing
import SwiftUI
@testable import Home

struct AppAppearanceTests {
    @Test func mapsToColorScheme() {
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    @Test func hasThreeCases() {
        #expect(AppAppearance.allCases.count == 3)
    }

    @Test func roundTripsRawValue() {
        #expect(AppAppearance(rawValue: "dark") == .dark)
    }
}
