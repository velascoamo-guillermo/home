import Testing
import Foundation
@testable import Casita

@Suite("CalendarSelectionStore") struct CalendarSelectionStoreTests {

    private func ephemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.calendar.\(UUID().uuidString)")!
    }

    @Test("defaults: nothing excluded, banner not dismissed")
    func defaults() {
        let store = CalendarSelectionStore(defaults: ephemeralDefaults())
        #expect(store.excludedIDs().isEmpty)
        #expect(store.isBannerDismissed == false)
    }

    @Test("excluded IDs round-trip across instances")
    func roundTrip() {
        let d = ephemeralDefaults()
        CalendarSelectionStore(defaults: d).setExcludedIDs(["work", "holidays"])
        #expect(CalendarSelectionStore(defaults: d).excludedIDs() == ["work", "holidays"])
    }

    @Test("dismissing the banner persists")
    func dismiss() {
        let d = ephemeralDefaults()
        CalendarSelectionStore(defaults: d).dismissBanner()
        #expect(CalendarSelectionStore(defaults: d).isBannerDismissed)
    }

    @Test("a non-array stored value reads as nothing excluded")
    func corrupt() {
        let d = ephemeralDefaults()
        d.set(42, forKey: CalendarSelectionStore.excludedKey)
        #expect(CalendarSelectionStore(defaults: d).excludedIDs().isEmpty)
    }
}
