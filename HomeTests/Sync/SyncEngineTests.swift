import Testing
import Foundation
@testable import Home

actor FakeGateway: RemoteGateway {
    private var pushed: [(OutboxOpKind, String)] = []
    private var failTables: Set<String> = []
    private var pullReturns: [String: [Data]] = [:]

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        if failTables.contains(table) { throw NSError(domain: "net", code: 1) }
        pushed.append((kind, table))
    }
    func pull(table: String, since: Date?) async throws -> [Data] { pullReturns[table] ?? [] }
    func setFail(_ t: String) async { failTables.insert(t) }
    func pushedCount() async -> Int { pushed.count }
    func setPull(_ t: String, _ data: [Data]) async { pullReturns[t] = data }
}

@Suite("SyncEngine push") @MainActor struct SyncEnginePushTests {
    private func make() async throws -> (SyncEngine, LocalStore, FakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("se-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = FakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }
    private func product() -> StockProduct {
        StockProduct(name: "Milk", icon: "i", packages: 1, looseUnits: 0, unitsPerPackage: 6)
    }

    @Test("successful push clears the outbox op")
    func pushClears() async throws {
        let (engine, store, gw) = try await make()
        try await store.upsert([product()], enqueue: true)
        try await engine.push()
        let count = await gw.pushedCount()
        #expect(count == 1)
        #expect(try await store.pendingOps().isEmpty)
    }

    @Test("failed push retains op and records error")
    func pushFails() async throws {
        let (engine, store, gw) = try await make()
        await gw.setFail("stock_products")
        try await store.upsert([product()], enqueue: true)
        try await engine.push()
        let ops = try await store.pendingOps()
        #expect(ops.count == 1)
        #expect(ops[0].attempts == 1)
    }
}

@Suite("SyncEngine pull") @MainActor struct SyncEnginePullTests {
    private func make() async throws -> (SyncEngine, LocalStore, FakeGateway) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sp-\(UUID().uuidString).sqlite")
        let store = try await LocalStore(url: url)
        let gw = FakeGateway()
        return (SyncEngine(local: store, gateway: gw), store, gw)
    }

    private func blob(id: UUID, name: String, updatedAt: Date, deletedAt: Date? = nil) throws -> Data {
        let p = StockProduct(id: id, name: name, icon: "i", packages: 1, looseUnits: 0,
                             unitsPerPackage: 6, updatedAt: updatedAt, deletedAt: deletedAt)
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return try e.encode(p)
    }

    @Test("pull inserts a new remote row locally without enqueueing")
    func pullInserts() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        await gw.setPull("stock_products", [try blob(id: id, name: "Milk", updatedAt: .now)])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Milk"])
        #expect(try await store.pendingOps().isEmpty)
    }

    @Test("newer local wins over older remote (LWW)")
    func localWins() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let newer = StockProduct(id: id, name: "Local", icon: "i", packages: 1, looseUnits: 0,
                                 unitsPerPackage: 6, updatedAt: .now)
        try await store.upsert([newer], enqueue: false)
        await gw.setPull("stock_products",
                         [try blob(id: id, name: "Remote", updatedAt: .now.addingTimeInterval(-60))])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Local"])
    }

    @Test("remote tombstone hides the row")
    func remoteTombstone() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        try await store.upsert([StockProduct(id: id, name: "Milk", icon: "i", packages: 1,
                                             looseUnits: 0, unitsPerPackage: 6)], enqueue: false)
        await gw.setPull("stock_products",
                         [try blob(id: id, name: "Milk", updatedAt: .now.addingTimeInterval(60),
                                   deletedAt: .now.addingTimeInterval(60))])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).isEmpty)
    }

    @Test("equal updatedAt: remote wins (tie goes to server)")
    func equalTimestampRemoteWins() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let ts = Date.now
        let local = StockProduct(id: id, name: "Local", icon: "i", packages: 1,
                                 looseUnits: 0, unitsPerPackage: 6, updatedAt: ts)
        try await store.upsert([local], enqueue: false)
        await gw.setPull("stock_products", [try blob(id: id, name: "Remote", updatedAt: ts)])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Remote"])
    }

    @Test("pull decodes Postgres timestamps with fractional seconds")
    func pullFractionalSeconds() async throws {
        let (engine, store, gw) = try await make()
        let id = UUID()
        let json: [String: Any] = [
            "id": id.uuidString, "name": "Milk", "icon": "i",
            "packages": 1, "loose_units": 0, "units_per_package": 6,
            "created_at": "2024-06-01T12:00:00.123456+00:00",
            "updated_at": "2024-06-01T12:00:00.654321+00:00"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        await gw.setPull("stock_products", [data])
        try await engine.pull(table: "stock_products")
        #expect(try await store.fetchAll(StockProduct.self).map(\.name) == ["Milk"])
    }

    @Test("cursor is advanced after pull")
    func cursorAdvanced() async throws {
        let (engine, store, gw) = try await make()
        let ts = Date.now
        await gw.setPull("stock_products", [try blob(id: UUID(), name: "Milk", updatedAt: ts)])
        try await engine.pull(table: "stock_products")
        let cursor = try await store.cursor(for: "stock_products")
        #expect(cursor != nil)
    }
}
