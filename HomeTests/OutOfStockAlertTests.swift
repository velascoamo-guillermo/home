import Testing
import Foundation
@testable import Casita

@Suite("OutOfStockInfo") @MainActor struct OutOfStockAlertTests {

    @Test("init stores product and needed, and each instance gets a distinct id")
    func storesFieldsAndDistinctId() {
        let product = StockProduct(name: "Filter",                                     packages: 0, looseUnits: 0, unitsPerPackage: 3)
        let a = OutOfStockInfo(product: product, needed: 2)
        let b = OutOfStockInfo(product: product, needed: 2)

        #expect(a.product.id == product.id)
        #expect(a.needed == 2)
        #expect(a.id != b.id)
    }
}
