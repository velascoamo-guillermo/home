import Testing
import Foundation
@testable import Casita

actor MenuEntryFakeGateway: RemoteGateway {
    private var pushed: [(OutboxOpKind, String)] = []
    private var pullReturns: [String: [Data]] = [:]

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        pushed.append((kind, table))
    }
    func pull(table: String, since: Date?) async throws -> [Data] { pullReturns[table] ?? [] }
    func pushedTables() async -> [String] { pushed.map(\.1) }
    func setPull(_ t: String, _ data: [Data]) async { pullReturns[t] = data }
}

@Suite("MenuEntry sync") @MainActor struct MenuEntrySyncTests {
    private func make() async throws -> (SyncEngine, LocalStore, MenuEntryFakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("me-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = MenuEntryFakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }

    @Test("menu_entries is a synced table")
    func isSyncedTable() {
        #expect(SyncEngine.syncedTables.contains("menu_entries"))
    }

    @Test("local upsert pushes to menu_entries and clears outbox")
    func pushRoundTrip() async throws {
        let (engine, store, gw) = try await make()
        let entry = MenuEntry(dayOfWeek: 2, slot: .dinner, mealId: UUID())
        try await store.upsert([entry], enqueue: true)
        try await engine.push()
        #expect(await gw.pushedTables() == ["menu_entries"])
        #expect(try await store.pendingOps().isEmpty)
    }

    @Test("pull reconciles a remote menu entry into LocalStore")
    func pullReconciles() async throws {
        let (engine, store, gw) = try await make()
        let entry = MenuEntry(dayOfWeek: 5, slot: .lunch, mealId: UUID())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        await gw.setPull("menu_entries", [try encoder.encode(entry)])
        try await engine.pull(table: "menu_entries")
        let fetched = try await store.fetchAll(MenuEntry.self)
        #expect(fetched.map(\.dayOfWeek) == [5])
        #expect(try await store.pendingOps().isEmpty)
    }

    @Test("decodes Supabase snake_case row")
    func decodesSnakeCase() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "day_of_week": 3,
          "slot": "dinner",
          "meal_id": "00000000-0000-0000-0000-000000000002",
          "created_at": "2026-07-21T10:00:00Z",
          "updated_at": "2026-07-21T10:00:00Z",
          "deleted_at": null
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(MenuEntry.self, from: json)
        #expect(entry.dayOfWeek == 3)
        #expect(entry.slot == .dinner)
        #expect(entry.mealId == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
    }
}
