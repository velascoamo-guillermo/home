import Testing
import Foundation
@testable import Casita

@Suite("OutOfStockInfo") @MainActor struct OutOfStockAlertTests {

    @Test("init stores the product and each instance gets a distinct id")
    func storesProductAndDistinctId() {
        let product = StockProduct(name: "Filter", level: .out)
        let a = OutOfStockInfo(product: product)
        let b = OutOfStockInfo(product: product)
        #expect(a.product.id == product.id)
        #expect(a.id != b.id)
    }

    @Test("message names the product without unit counts")
    func message() {
        let info = OutOfStockInfo(product: StockProduct(name: "Filter", level: .out))
        #expect(info.message == "Filter is out of stock. Restock it — the task was marked done anyway.")
    }
}
