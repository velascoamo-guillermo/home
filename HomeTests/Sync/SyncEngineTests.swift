import Testing
import Foundation
@testable import Home

actor FakeGateway: RemoteGateway {
    private var pushed: [(OutboxOpKind, String)] = []
    private var failTables: Set<String> = []
    var pullReturns: [String: [Data]] = [:]

    func push(kind: OutboxOpKind, table: String, payload: Data) async throws {
        if failTables.contains(table) { throw NSError(domain: "net", code: 1) }
        pushed.append((kind, table))
    }
    func pull(table: String, since: Date?) async throws -> [Data] { pullReturns[table] ?? [] }
    func setFail(_ t: String) { failTables.insert(t) }
    func pushedCount() -> Int { pushed.count }
    func setPull(_ t: String, _ data: [Data]) { pullReturns[t] = data }
}

@Suite("SyncEngine push") struct SyncEnginePushTests {
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
