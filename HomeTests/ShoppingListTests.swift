import Testing
import Foundation
@testable import Casita

@Suite("SupabaseStore – shoppingList") @MainActor struct ShoppingListTests {

    @Test("shoppingList holds Out and Low products plus anything marked needed")
    func membership() {
        let store = SupabaseStore.makeTest()
        store.stockProducts = [
            StockProduct(name: "Milk", level: .out),
            StockProduct(name: "Bread", level: .low),
            StockProduct(name: "Rice", level: .medium),
            StockProduct(name: "Oil", level: .full),
            StockProduct(name: "Eggs", level: .full, needed: true),
        ]
        #expect(store.shoppingList.map(\.name).sorted() == ["Bread", "Eggs", "Milk"])
    }

    @Test("shoppingList is empty when everything is Medium or Full")
    func emptyWhenStocked() {
        let store = SupabaseStore.makeTest()
        store.stockProducts = [StockProduct(name: "Rice", level: .medium),
                               StockProduct(name: "Oil", level: .full)]
        #expect(store.shoppingList.isEmpty)
    }

    @Test("replenish sets Full, clears needed and drops the product from the list")
    func replenishLeavesList() async throws {
        let store = SupabaseStore.makeTest()
        let milk = StockProduct(name: "Milk", level: .low, needed: true)
        store.stockProducts = [milk]

        try await store.replenish(milk)

        #expect(store.stockProducts.first?.level == .full)
        #expect(store.stockProducts.first?.needed == false)
        #expect(store.shoppingList.isEmpty)
    }
}
