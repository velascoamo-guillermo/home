import Testing
import Foundation
import SQLite3
@testable import Casita

@Suite("SupabaseStore.replenish (batch)") @MainActor struct StockBatchReplenishTests {

    private func seeded(_ products: [StockProduct], url: URL = BudgetFixtures.tempURL()) async throws -> SupabaseStore {
        let store = await BudgetFixtures.makeStore(url: url)
        for p in products { try await store.addProduct(p) }
        for op in try await store._local?.pendingOps() ?? [] { try await store._local?.deleteOp(seq: op.seq) }
        return store
    }

    @Test("replenishes every product to full, not needed, with one outbox op each")
    func replenishesAll() async throws {
        let a = StockProduct(name: "Milk", level: .out)
        let b = StockProduct(name: "Eggs", level: .low, needed: true)
        let keep = StockProduct(name: "Rice", level: .low)
        let store = try await seeded([a, b, keep])

        try await store.replenish([a, b])

        let byId = Dictionary(uniqueKeysWithValues: store.stockProducts.map { ($0.id, $0) })
        #expect(byId[a.id]?.level == .full && byId[a.id]?.needed == false)
        #expect(byId[b.id]?.level == .full && byId[b.id]?.needed == false)
        #expect(byId[keep.id]?.level == .low)
        let ops = try await store._local?.pendingOps() ?? []
        #expect(Set(ops.map(\.entityId)) == [a.id, b.id])
        #expect(ops.count == 2)
    }

    @Test("an empty batch is a no-op")
    func emptyBatch() async throws {
        let store = try await seeded([])
        try await store.replenish([])
        #expect(try await store._local?.pendingOps().isEmpty == true)
    }

    @Test("a failing transaction leaves memory and disk untouched")
    func allOrNothing() async throws {
        let url = BudgetFixtures.tempURL()
        let a = StockProduct(name: "Milk", level: .out)
        let b = StockProduct(name: "Eggs", level: .low)
        let store = try await seeded([a, b], url: url)

        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        #expect(sqlite3_exec(db, "DROP TABLE outbox", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        await #expect(throws: (any Error).self) { try await store.replenish([a, b]) }

        #expect(store.stockProducts.allSatisfy { $0.level != .full })
        let reloaded = await BudgetFixtures.makeStore(url: url)
        #expect(reloaded.stockProducts.allSatisfy { $0.level != .full })
    }
}
