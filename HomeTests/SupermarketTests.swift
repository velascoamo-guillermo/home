import Testing
import Foundation
@testable import Home

@Suite("Supermarket") @MainActor struct SupermarketTests {
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
}
