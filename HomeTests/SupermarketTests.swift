import Testing
import Foundation
@testable import Home

@Suite("Supermarket") struct SupermarketTests {
    @Test("raw values are stable lowercase strings")
    func rawValues() {
        #expect(Supermarket.carrefour.rawValue == "carrefour")
        #expect(Supermarket.mercadona.rawValue == "mercadona")
    }

    @Test("displayName is human readable")
    func displayName() {
        #expect(Supermarket.carrefour.displayName == "Carrefour")
        #expect(Supermarket.mercadona.displayName == "Mercadona")
    }

    @Test("allCases covers both")
    func allCases() {
        #expect(Supermarket.allCases.count == 2)
    }

    @Test("Codable round-trip preserves raw value")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for market in Supermarket.allCases {
            let data = try encoder.encode(market)
            let decoded = try decoder.decode(Supermarket.self, from: data)
            #expect(decoded == market)
        }
    }
}
