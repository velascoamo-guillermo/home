import Testing
import Foundation
@testable import Casita

@Suite("SupabaseStore sync status", .serialized) @MainActor struct SupabaseStoreSyncStatusTests {
    typealias F = BudgetFixtures

    @Test("no sync has run when sync is disabled")
    func disabledHasNoTimestamp() async {
        let store = await F.makeStore(syncEnabled: false)
        #expect(store.lastSyncAt == nil)
    }

    @Test("loading with sync stamps the time the full pass finished")
    func loadStamps() async throws {
        let before = Date.now
        let store = await F.makeStore(syncEnabled: true, gateway: InMemoryRemote())
        let stamped = try #require(store.lastSyncAt)
        #expect(stamped >= before)
    }

    @Test("refreshing moves the timestamp forward")
    func refreshStamps() async throws {
        let store = await F.makeStore(syncEnabled: true, gateway: InMemoryRemote())
        let first = try #require(store.lastSyncAt)
        try await Task.sleep(for: .milliseconds(20))
        await store.refreshFromLocal()
        #expect(try #require(store.lastSyncAt) > first)
    }

    @Test("an offline change counts as pending until it is uploaded")
    func pendingCount() async throws {
        let offline = await F.makeStore(syncEnabled: false)
        try await offline.addTask(HouseholdTask(title: "Descale kettle", intervalDays: 30, nextDueDate: .now))
        #expect(await offline.pendingChangeCount() == 1)

        let online = await F.makeStore(syncEnabled: true, gateway: InMemoryRemote())
        try await online.addTask(HouseholdTask(title: "Descale kettle", intervalDays: 30, nextDueDate: .now))
        var pending = await online.pendingChangeCount()
        let deadline = ContinuousClock.now + .seconds(3)
        while pending != 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
            // The single-flight sync can lose the race to a concurrent sync (e.g. the
            // reconnect observer, or another test's store under CI load) and drop this
            // push; nudge a retry so the outbox still drains within the deadline.
            await online.refreshFromLocal()
            pending = await online.pendingChangeCount()
        }
        #expect(pending == 0)
    }

    @Test("pending count is zero before the local store exists")
    func pendingWithoutLocal() async {
        let store = SupabaseStore.makeTest()
        #expect(await store.pendingChangeCount() == 0)
    }
}
