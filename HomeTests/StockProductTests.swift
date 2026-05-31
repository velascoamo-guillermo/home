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
    }

    @Test("replenished adds one full package")
    func replenish() {
        let result = make(packages: 1, loose: 2, perPackage: 6).replenished()
        #expect(result.packages == 2)
        #expect(result.looseUnits == 2)
    }
}
