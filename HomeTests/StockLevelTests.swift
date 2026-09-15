import Testing
import Foundation
@testable import Casita

@Suite("StockLevel") @MainActor struct StockLevelTests {

    @Test("levels order out < low < medium < full")
    func ordering() {
        #expect([StockLevel.full, .out, .medium, .low].sorted() == [.out, .low, .medium, .full])
        #expect(StockLevel.out < .low)
        #expect(StockLevel.medium < .full)
        #expect(!(StockLevel.full < .full))
    }

    @Test("steppedDown walks full→medium→low→out and stays at out")
    func steppedDown() {
        #expect(StockLevel.full.steppedDown() == .medium)
        #expect(StockLevel.medium.steppedDown() == .low)
        #expect(StockLevel.low.steppedDown() == .out)
        #expect(StockLevel.out.steppedDown() == .out)
    }

    @Test("steppedUp walks out→low→medium→full and stays at full")
    func steppedUp() {
        #expect(StockLevel.out.steppedUp() == .low)
        #expect(StockLevel.low.steppedUp() == .medium)
        #expect(StockLevel.medium.steppedUp() == .full)
        #expect(StockLevel.full.steppedUp() == .full)
    }

    @Test("only out and low need restocking")
    func needsRestock() {
        #expect(StockLevel.out.needsRestock)
        #expect(StockLevel.low.needsRestock)
        #expect(!StockLevel.medium.needsRestock)
        #expect(!StockLevel.full.needsRestock)
    }

    @Test("display names and gauge segments")
    func presentation() {
        #expect(StockLevel.allCases.map(\.displayName) == ["Out", "Low", "Medium", "Full"])
        #expect(StockLevel.allCases.map(\.filledSegments) == [0, 1, 2, 3])
    }

    @Test("unit mapping: 0/0 out, loose-only low, one package medium, two or more full")
    func mapping() {
        #expect(StockLevel.from(packages: 0, looseUnits: 0) == .out)
        #expect(StockLevel.from(packages: 0, looseUnits: 1) == .low)
        #expect(StockLevel.from(packages: 0, looseUnits: 9) == .low)
        #expect(StockLevel.from(packages: 1, looseUnits: 0) == .medium)
        #expect(StockLevel.from(packages: 1, looseUnits: 5) == .medium)
        #expect(StockLevel.from(packages: 2, looseUnits: 0) == .full)
        #expect(StockLevel.from(packages: 4, looseUnits: 3) == .full)
    }

    @Test("encodes as its raw string")
    func codable() throws {
        let data = try JSONEncoder().encode([StockLevel.medium])
        #expect(String(decoding: data, as: UTF8.self) == #"["medium"]"#)
        #expect(try JSONDecoder().decode([StockLevel].self, from: Data(#"["low"]"#.utf8)) == [.low])
    }
}
