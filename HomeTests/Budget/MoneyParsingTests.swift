import Testing
import Foundation
@testable import Casita

@Suite("Money parsing") @MainActor struct MoneyParsingTests {

    @Test("accepts dot or comma decimals, € and spaces", arguments: [
        ("12", 1_200), ("12.5", 1_250), ("12,5", 1_250), ("12,50", 1_250), ("12.05", 1_205),
        ("0,99", 99), (",5", 50), ("12,", 1_200), ("€ 12.50", 1_250), ("12.50 €", 1_250),
        ("  7 ", 700), ("1000000", 100_000_000),
    ])
    func valid(input: String, cents: Int) {
        #expect(Money.parseCents(input) == cents)
    }

    @Test("rejects anything that is not a plain amount", arguments: [
        "", " ", ".", ",", "abc", "-5", "1,234", "1.234,56", "12.345", "1e3", "١٢", "1234567890",
    ])
    func invalid(input: String) {
        #expect(Money.parseCents(input) == nil)
    }

    @Test("editText round-trips through parseCents")
    func editText() {
        #expect(Money.editText(cents: 5_000) == "50.00")
        #expect(Money.editText(cents: 7) == "0.07")
        for cents in [0, 1, 99, 100, 12_345, 100_000_000] {
            #expect(Money.parseCents(Money.editText(cents: cents)) == cents)
        }
    }
}
