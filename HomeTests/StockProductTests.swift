import Testing
import Foundation
@testable import Home

@Suite("StockProduct – quantity math") @MainActor struct StockProductTests {

    private func make(packages: Int, loose: Int, perPackage: Int) -> StockProduct {
        StockProduct(name: "Milk", icon: "takeoutbag.and.cup.and.straw.fill",
                     packages: packages, looseUnits: loose, unitsPerPackage: perPackage)
    }

    @Test("totalUnits = packages * unitsPerPackage + looseUnits")
    func totalUnits() {
        #expect(make(packages: 2, loose: 3, perPackage: 6).totalUnits == 15)
        #expect(make(packages: 0, loose: 0, perPackage: 6).totalUnits == 0)
    }

    @Test("consumingOneUnit decrements a loose unit when loose > 0")
    func consumeLoose() {
        let result = make(packages: 1, loose: 3, perPackage: 6).consumingOneUnit()
        #expect(result?.packages == 1)
        #expect(result?.looseUnits == 2)
    }

    @Test("consumingOneUnit opens a package when loose == 0")
    func consumeOpensPackage() {
        let result = make(packages: 2, loose: 0, perPackage: 6).consumingOneUnit()
        #expect(result?.packages == 1)
        #expect(result?.looseUnits == 5)
    }

    @Test("consumingOneUnit returns nil when totalUnits == 0")
    func consumeOutOfStock() {
        #expect(make(packages: 0, loose: 0, perPackage: 6).consumingOneUnit() == nil)
    }

    @Test("consuming the very last loose unit reaches zero")
    func consumeLastUnit() {
        let result = make(packages: 0, loose: 1, perPackage: 6).consumingOneUnit()
        #expect(result?.totalUnits == 0)
        #expect(result?.packages == 0)
        #expect(result?.looseUnits == 0)
    }

    @Test("Codable round-trip preserves snake_case keys and field values")
    func codableRoundTrip() throws {
        let product = make(packages: 2, loose: 3, perPackage: 6)
        let encoder = JSONEncoder()
        let data = try encoder.encode(product)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["loose_units"] as? Int == 3)
        #expect(json["units_per_package"] as? Int == 6)
        #expect(json["created_at"] == nil)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StockProduct.self, from: data)
        #expect(decoded.packages == product.packages)
        #expect(decoded.looseUnits == product.looseUnits)
        #expect(decoded.unitsPerPackage == product.unitsPerPackage)
        #expect(decoded.name == product.name)
    }

    @Test("replenished adds one full package")
    func replenish() {
        let result = make(packages: 1, loose: 2, perPackage: 6).replenished()
        #expect(result.packages == 2)
        #expect(result.looseUnits == 2)
    }

    @Test("consuming(units:) decrements N loose units")
    func consumeNLoose() {
        let result = make(packages: 1, loose: 5, perPackage: 6).consuming(units: 3)
        #expect(result?.packages == 1)
        #expect(result?.looseUnits == 2)
    }

    @Test("consuming(units:) spans a package boundary")
    func consumeAcrossPackage() {
        let result = make(packages: 1, loose: 2, perPackage: 6).consuming(units: 4)
        #expect(result?.packages == 0)
        #expect(result?.looseUnits == 4)
    }

    @Test("consuming(units:) consuming a full package exactly")
    func consumeFullPackage() {
        let result = make(packages: 1, loose: 0, perPackage: 6).consuming(units: 6)
        #expect(result?.packages == 0)
        #expect(result?.looseUnits == 0)
    }

    @Test("consuming(units:) returns nil when totalUnits < n")
    func consumeTooMany() {
        #expect(make(packages: 1, loose: 0, perPackage: 6).consuming(units: 8) == nil)
    }

    @Test("consuming(units: 0) returns nil")
    func consumeZero() {
        #expect(make(packages: 1, loose: 2, perPackage: 6).consuming(units: 0) == nil)
    }

    @Test("consumingOneUnit still consumes exactly one unit")
    func consumeOneDelegate() {
        let result = make(packages: 1, loose: 2, perPackage: 6).consumingOneUnit()
        #expect(result?.looseUnits == 1)
        #expect(result?.packages == 1)
    }
}
