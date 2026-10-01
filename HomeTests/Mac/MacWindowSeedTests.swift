#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("MacWindowSeed") @MainActor struct MacWindowSeedTests {
    private let fixedID = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!
    private let petID = UUID(uuidString: "87654321-4321-8765-4321-876543218765")!

    @Test("a seed round-trips through Codable for window restoration")
    func codable() throws {
        let seed = MacWindowSeed(id: fixedID, item: .pet(petID))
        let data = try JSONEncoder().encode(seed)
        #expect(try JSONDecoder().decode(MacWindowSeed.self, from: data) == seed)
    }

    @Test("JSON encoding is stable for window state restoration")
    func goldenEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let today = String(decoding: try encoder.encode(MacWindowSeed(id: fixedID, item: .today)), as: UTF8.self)
        #expect(today == #"{"id":"12345678-1234-5678-1234-567812345678","item":{"today":{}}}"#)
        let pet = String(decoding: try encoder.encode(MacWindowSeed(id: fixedID, item: .pet(petID))), as: UTF8.self)
        #expect(pet == #"{"id":"12345678-1234-5678-1234-567812345678","item":{"pet":{"_0":"87654321-4321-8765-4321-876543218765"}}}"#)
    }

    @Test("a new seed carries the item and always gets a distinct id, even for the same item")
    func newSeedIsDistinct() {
        let first = MacWindowSeed.new(.shopping)
        let second = MacWindowSeed.new(.shopping)
        #expect(first.item == .shopping)
        #expect(second.item == .shopping)
        #expect(first.id != second.id)
        #expect(first != second)
    }

    @Test("changing the item keeps the window's identity")
    func selectingKeepsID() {
        var seed = MacWindowSeed.new(.today)
        let id = seed.id
        seed.item = .budget
        #expect(seed.id == id)
        #expect(seed.item == .budget)
    }
}
#endif
