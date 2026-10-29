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

    @Test("a failure after the first product is written rolls the whole batch back")
    func allOrNothing() async throws {
        let url = BudgetFixtures.tempURL()
        let a = StockProduct(name: "Milk", level: .out)
        let b = StockProduct(name: "Eggs", level: .low)
        let store = try await seeded([a, b], url: url)

        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        let trigger = """
            CREATE TRIGGER fail_second BEFORE INSERT ON outbox
            WHEN NEW.entity_id = '\(b.id.uuidString)'
            BEGIN SELECT RAISE(ABORT, 'boom'); END;
            """
        #expect(sqlite3_exec(db, trigger, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        await #expect(throws: (any Error).self) { try await store.replenish([a, b]) }

        #expect(store.stockProducts.allSatisfy { $0.level != .full })
        let reloaded = await BudgetFixtures.makeStore(url: url)
        #expect(reloaded.stockProducts.allSatisfy { $0.level != .full })
        #expect(try await reloaded._local?.pendingOps().isEmpty == true)
    }

    @Test("a batch publishes exactly one stockProducts change")
    func singleMutation() async throws {
        let a = StockProduct(name: "Milk", level: .out)
        let b = StockProduct(name: "Eggs", level: .low)
        let c = StockProduct(name: "Rice", level: .low)
        let store = try await seeded([a, b, c])

        let counter = ChangeCounter(store)
        counter.arm()

        try await store.replenish([a, b, c])

        #expect(counter.count == 1)
    }
}

/// Counts `stockProducts` change notifications; re-arms after each one.
@MainActor private final class ChangeCounter {
    private(set) var count = 0
    private let store: SupabaseStore
    init(_ store: SupabaseStore) { self.store = store }

    func arm() {
        withObservationTracking { _ = store.stockProducts } onChange: {
            MainActor.assumeIsolated { self.count += 1 }
            Task { @MainActor in self.arm() } // re-arming inline would re-fire within the same willSet
        }
    }
}
