import Testing
import Foundation
@testable import Casita

@Suite("StockProduct") @MainActor struct StockProductTests {

    @Test("Codable round-trip keeps level and snake_case keys and never emits unit counts")
    func codableRoundTrip() throws {
        let product = StockProduct(name: "Milk", level: .low, supermarket: .mercadona, category: .food)
        let data = try JSONEncoder().encode(product)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["level"] as? String == "low")
        #expect(json["created_at"] != nil)
        #expect(json["packages"] == nil)
        #expect(json["loose_units"] == nil)
        #expect(json["units_per_package"] == nil)
        let decoded = try JSONDecoder().decode(StockProduct.self, from: data)
        #expect(decoded.level == .low)
        #expect(decoded.name == "Milk")
        #expect(decoded.supermarket == .mercadona)
        #expect(decoded.category == .food)
    }

    @Test("supermarket and category default to nil")
    func metadataDefaultsNil() {
        let p = StockProduct(name: "Milk", level: .full)
        #expect(p.supermarket == nil)
        #expect(p.category == nil)
    }

    @Test("decodes when supermarket and category keys are absent")
    func codableDecodesWithoutMetadata() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Milk","level":"full",
         "created_at":0,"updated_at":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StockProduct.self, from: json)
        #expect(decoded.supermarket == nil)
        #expect(decoded.category == nil)
    }

    @Test("decodes null JSON values for supermarket and category as nil")
    func codableDecodesNullMetadata() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Milk","level":"full",
         "supermarket":null,"category":null,
         "created_at":0,"updated_at":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StockProduct.self, from: json)
        #expect(decoded.supermarket == nil)
        #expect(decoded.category == nil)
    }

    @Test("decodes legacy payloads that still carry icon and unit keys")
    func codableIgnoresLegacyIcon() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Milk","icon":"shippingbox",
         "packages":1,"loose_units":0,"units_per_package":6,
         "created_at":0,"updated_at":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StockProduct.self, from: json)
        #expect(decoded.name == "Milk")
        #expect(decoded.level == .medium)
    }
}
