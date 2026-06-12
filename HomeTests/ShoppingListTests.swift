import Testing
import Foundation
@testable import Home

@Suite("SupabaseStore – shoppingList") @MainActor struct ShoppingListTests {

    private func product(_ name: String, packages: Int, loose: Int,
                         market: Supermarket? = nil) -> StockProduct {
        StockProduct(name: name, icon: "x", packages: packages,
                     looseUnits: loose, unitsPerPackage: 6, supermarket: market)
    }

    @Test("shoppingList contains only out-of-stock products")
    func onlyOutOfStock() {
        let store = SupabaseStore()
        store.stockProducts = [
            product("Milk", packages: 0, loose: 0),
            product("Eggs", packages: 1, loose: 0),
            product("Bleach", packages: 0, loose: 0),
        ]
        let names = store.shoppingList.map(\.name).sorted()
        #expect(names == ["Bleach", "Milk"])
    }

    @Test("shoppingList is empty when everything is stocked")
    func emptyWhenStocked() {
        let store = SupabaseStore()
        store.stockProducts = [product("Eggs", packages: 1, loose: 0)]
        #expect(store.shoppingList.isEmpty)
    }
}
