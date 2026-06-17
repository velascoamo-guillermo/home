import Testing
import Foundation
@testable import Home

@Suite("LocalStore") struct LocalStoreTests {
    private func make() async throws -> LocalStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ls-\(UUID().uuidString).sqlite")
        return try await LocalStore(url: url)
    }

    private func product(_ name: String) -> StockProduct {
        StockProduct(name: name, icon: "i", packages: 1, looseUnits: 0, unitsPerPackage: 6)
    }

    @Test("upsert then fetchAll returns the row")
    func upsertFetch() async throws {
        let store = try await make()
        try await store.upsert([product("Milk")], enqueue: false)
        let all = try await store.fetchAll(StockProduct.self)
        #expect(all.map(\.name) == ["Milk"])
    }

    @Test("fetchAll excludes tombstoned rows")
    func excludesTombstones() async throws {
        let store = try await make()
        let p = product("Milk")
        try await store.upsert([p], enqueue: false)
        try await store.softDelete(p, enqueue: false)
        #expect(try await store.fetchAll(StockProduct.self).isEmpty)
    }

    @Test("optimistic mutate writes entity AND outbox atomically")
    func mutateEnqueues() async throws {
        let store = try await make()
        try await store.upsert([product("Milk")], enqueue: true)
        let pending = try await store.pendingOps()
        #expect(pending.count == 1)
        #expect(pending[0].tableName == "stock_products")
        #expect(pending[0].kind == .update)
    }
}
