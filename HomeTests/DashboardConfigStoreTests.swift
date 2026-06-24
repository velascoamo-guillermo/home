import Testing
import Foundation
@testable import Home

@Suite("DashboardConfigStore") struct DashboardConfigStoreTests {

    private func ephemeralDefaults() -> UserDefaults {
        // Distinct, unsynced suite per test instance; no app-group entitlement needed.
        let suite = "test.dashboard.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test("load returns default when nothing stored")
    func loadDefault() {
        let store = DashboardConfigStore(defaults: ephemeralDefaults())
        #expect(store.load() == .default)
    }

    @Test("save then load round-trips")
    func roundTrip() {
        let d = ephemeralDefaults()
        let store = DashboardConfigStore(defaults: d)
        let cfg = DashboardConfig(cards: [.appointments, .upcomingTasks])
        store.save(cfg)
        #expect(DashboardConfigStore(defaults: d).load() == cfg)
    }

    @Test("corrupt stored data falls back to default")
    func corrupt() {
        let d = ephemeralDefaults()
        d.set(Data("not json".utf8), forKey: DashboardConfigStore.key)
        #expect(DashboardConfigStore(defaults: d).load() == .default)
    }
}
