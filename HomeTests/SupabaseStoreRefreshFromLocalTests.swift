// HomeTests/SupabaseStoreRefreshFromLocalTests.swift
import Testing
import Foundation
import Supabase
@testable import Casita

@Suite("SupabaseStore.refreshFromLocal") @MainActor struct SupabaseStoreRefreshFromLocalTests {

    private func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1")!,
            supabaseKey: "test",
            options: .init(auth: .init(autoRefreshToken: false, emitLocalSessionAsInitialSession: false))
        )
    }

    @Test("re-hydrates in-memory state from a local store written by another process")
    func rehydratesFromLocal() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rfl-\(UUID().uuidString).sqlite")
        let store = SupabaseStore(client: makeClient(), localURL: url, syncEnabled: false)
        await store.loadAll()
        #expect(store.householdTasks.isEmpty)

        // Simulate the widget intent writing to the same sqlite file via its own LocalStore.
        let local = try await LocalStore(url: url)
        let task = HouseholdTask(title: "Feed cat", icon: "pawprint", intervalDays: 1, nextDueDate: .now)
        try await local.upsert([task], enqueue: false)

        await store.refreshFromLocal()

        #expect(store.householdTasks.contains { $0.id == task.id })
    }

    @Test("is a no-op when the local store hasn't been initialized yet")
    func noOpWithoutLocalStore() async {
        let store = SupabaseStore(client: makeClient(), syncEnabled: false)
        await store.refreshFromLocal()
        #expect(store.householdTasks.isEmpty)
    }
}
