import Testing
import Foundation
@testable import Home

@Suite("SyncableEntity") @MainActor struct SyncableEntityTests {
    @Test("StockProduct exposes table name and sync timestamps")
    func conformance() {
        var p = StockProduct(name: "Milk", icon: "i", packages: 1, looseUnits: 0, unitsPerPackage: 6)
        #expect(StockProduct.tableName == "stock_products")
        p.deletedAt = .now
        #expect(p.deletedAt != nil)
        #expect(p.updatedAt <= Date.now.addingTimeInterval(1))
    }
}
