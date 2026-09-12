import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct StockProductNeededTests {
    @Test func decodesLegacyPayloadWithoutNeededAsFalse() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Milk","icon":"shippingbox",
         "packages":1,"loose_units":0,"units_per_package":6,
         "created_at":"2026-01-01T10:00:00Z","updated_at":"2026-01-01T10:00:00Z"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let product = try decoder.decode(StockProduct.self, from: json)
        #expect(product.needed == false)
    }

    @Test func decodesNeededWhenPresent() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000002","name":"Milk","icon":"shippingbox",
         "packages":1,"loose_units":0,"units_per_package":6,"needed":true,
         "created_at":"2026-01-01T10:00:00Z","updated_at":"2026-01-01T10:00:00Z"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let product = try decoder.decode(StockProduct.self, from: json)
        #expect(product.needed == true)
    }

    @Test func encodeRoundTripsNeeded() throws {
        var product = StockProduct(name: "Milk", icon: "shippingbox",
                                   packages: 1, looseUnits: 0, unitsPerPackage: 6)
        product.needed = true
        let data = try JSONEncoder().encode(product)
        let decoded = try JSONDecoder().decode(StockProduct.self, from: data)
        #expect(decoded.needed == true)
    }

    @Test func replenishedClearsNeeded() {
        var product = StockProduct(name: "Milk", icon: "shippingbox",
                                   packages: 0, looseUnits: 0, unitsPerPackage: 6)
        product.needed = true
        let replenished = product.replenished()
        #expect(replenished.needed == false)
        #expect(replenished.packages == 1)
    }

    @Test func shoppingListIncludesNeededWithStock() {
        let store = SupabaseStore.makeTest()
        var inStockNeeded = StockProduct(name: "A", icon: "shippingbox",
                                         packages: 1, looseUnits: 0, unitsPerPackage: 1)
        inStockNeeded.needed = true
        let inStockFine = StockProduct(name: "B", icon: "shippingbox",
                                       packages: 1, looseUnits: 0, unitsPerPackage: 1)
        let outOfStock = StockProduct(name: "C", icon: "shippingbox",
                                      packages: 0, looseUnits: 0, unitsPerPackage: 1)
        store.stockProducts = [inStockNeeded, inStockFine, outOfStock]
        #expect(Set(store.shoppingList.map(\.name)) == ["A", "C"])
    }
}
