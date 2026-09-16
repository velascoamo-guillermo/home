import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct StockProductNeededTests {
    @Test func decodesPayloadWithoutNeededAsFalse() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Milk","level":"full",
         "created_at":"2026-01-01T10:00:00Z","updated_at":"2026-01-01T10:00:00Z"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let product = try decoder.decode(StockProduct.self, from: json)
        #expect(product.needed == false)
    }

    @Test func decodesNeededWhenPresent() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000002","name":"Milk","level":"full","needed":true,
         "created_at":"2026-01-01T10:00:00Z","updated_at":"2026-01-01T10:00:00Z"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let product = try decoder.decode(StockProduct.self, from: json)
        #expect(product.needed == true)
    }

    @Test func encodeRoundTripsNeeded() throws {
        let product = StockProduct(name: "Milk", level: .full, needed: true)
        let data = try JSONEncoder().encode(product)
        let decoded = try JSONDecoder().decode(StockProduct.self, from: data)
        #expect(decoded.needed == true)
    }

    @Test func replenishedSetsFullAndClearsNeeded() {
        let replenished = StockProduct(name: "Milk", level: .out, needed: true).replenished()
        #expect(replenished.needed == false)
        #expect(replenished.level == .full)
    }

    @Test func isOnShoppingListCoversOutLowAndNeeded() {
        #expect(StockProduct(name: "A", level: .out).isOnShoppingList)
        #expect(StockProduct(name: "A", level: .low).isOnShoppingList)
        #expect(!StockProduct(name: "A", level: .medium).isOnShoppingList)
        #expect(!StockProduct(name: "A", level: .full).isOnShoppingList)
        #expect(StockProduct(name: "A", level: .full, needed: true).isOnShoppingList)
    }
}
