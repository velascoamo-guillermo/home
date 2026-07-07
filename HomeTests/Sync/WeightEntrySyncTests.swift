import Testing
import Foundation
@testable import Casita

actor WeightFakeGateway: RemoteGateway {
    private var pushed: [(OutboxOpKind, String)] = []
    private var pullReturns: [String: [Data]] = [:]

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        pushed.append((kind, table))
    }
    func pull(table: String, since: Date?) async throws -> [Data] { pullReturns[table] ?? [] }
    func pushedTables() async -> [String] { pushed.map(\.1) }
    func setPull(_ t: String, _ data: [Data]) async { pullReturns[t] = data }
}

@Suite("WeightEntry sync") @MainActor struct WeightEntrySyncTests {
    private func make() async throws -> (SyncEngine, LocalStore, WeightFakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("we-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = WeightFakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }

    @Test("weight_entries is a synced table")
    func isSyncedTable() {
        #expect(SyncEngine.syncedTables.contains("weight_entries"))
    }

    @Test("local upsert pushes to weight_entries and clears outbox")
    func pushRoundTrip() async throws {
        let (engine, store, gw) = try await make()
        let entry = WeightEntry(petId: UUID(), date: .now, weightKg: 12.5)
        try await store.upsert([entry], enqueue: true)
        try await engine.push()
        #expect(await gw.pushedTables() == ["weight_entries"])
        #expect(try await store.pendingOps().isEmpty)
    }

    @Test("pull reconciles a remote weight entry into LocalStore")
    func pullReconciles() async throws {
        let (engine, store, gw) = try await make()
        let entry = WeightEntry(petId: UUID(), date: .now, weightKg: 8.2)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        await gw.setPull("weight_entries", [try encoder.encode(entry)])
        try await engine.pull(table: "weight_entries")
        let fetched = try await store.fetchAll(WeightEntry.self)
        #expect(fetched.map(\.weightKg) == [8.2])
        #expect(try await store.pendingOps().isEmpty)
    }
}
