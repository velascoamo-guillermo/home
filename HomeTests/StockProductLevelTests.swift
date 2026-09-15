import Testing
import Foundation
@testable import Casita

@Suite("StockProduct – level") @MainActor struct StockProductLevelTests {

    private func decode(_ json: String) throws -> StockProduct {
        try JSONDecoder().decode(StockProduct.self, from: Data(json.utf8))
    }

    @Test("level initializer stores the level and defaults needed to false")
    func levelInit() {
        let p = StockProduct(name: "Milk", level: .medium)
        #expect(p.level == .medium)
        #expect(p.needed == false)
    }

    @Test("decoding prefers an explicit level over unit counts")
    func explicitLevelWins() throws {
        let p = try decode("""
        {"id":"\(UUID().uuidString)","name":"Milk","level":"low",
         "packages":3,"loose_units":0,"units_per_package":6}
        """)
        #expect(p.level == .low)
    }

    @Test("legacy blobs without level derive it from their units")
    func legacyMapping() throws {
        let rows: [(packages: Int, loose: Int, expected: StockLevel)] = [
            (0, 0, .out), (0, 1, .low), (0, 7, .low),
            (1, 0, .medium), (1, 5, .medium), (2, 0, .full), (4, 3, .full),
        ]
        for row in rows {
            let p = try decode("""
            {"id":"\(UUID().uuidString)","name":"Milk",
             "packages":\(row.packages),"loose_units":\(row.loose),"units_per_package":6}
            """)
            #expect(p.level == row.expected, "packages \(row.packages), loose \(row.loose)")
        }
    }

    @Test("a blob with neither level nor unit keys decodes as out")
    func missingEverything() throws {
        let p = try decode(#"{"id":"\#(UUID().uuidString)","name":"Milk"}"#)
        #expect(p.level == .out)
    }

    @Test("encoding emits the level key")
    func encodesLevel() throws {
        let data = try JSONEncoder().encode(StockProduct(name: "Milk", level: .medium))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["level"] as? String == "medium")
    }

    @Test("withLevel returns a copy with only the level changed")
    func withLevel() {
        let p = StockProduct(name: "Milk", level: .full, needed: true, supermarket: .mercadona, category: .food)
        let q = p.withLevel(.low)
        #expect(q.level == .low)
        #expect(q.id == p.id)
        #expect(q.name == "Milk")
        #expect(q.needed == true)
        #expect(q.supermarket == .mercadona)
        #expect(q.category == .food)
    }

    @Test("steppedDown lowers one level and keeps out at out")
    func steppedDown() {
        #expect(StockProduct(name: "Milk", level: .full).steppedDown().level == .medium)
        #expect(StockProduct(name: "Milk", level: .out).steppedDown().level == .out)
    }

    @Test("replenished sets full and clears needed")
    func replenished() {
        let p = StockProduct(name: "Milk", level: .low, needed: true).replenished()
        #expect(p.level == .full)
        #expect(p.needed == false)
    }
}
