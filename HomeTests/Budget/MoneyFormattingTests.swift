import Testing
import Foundation
@testable import Casita

@Suite("Money formatting") @MainActor struct MoneyFormattingTests {
    private let us = Locale(identifier: "en_US")

    @Test("formats cents as EUR without floating point drift")
    func format() {
        #expect(Money.format(cents: 21_258, locale: us) == "€212.58")
        #expect(Money.format(cents: 185_500, locale: us) == "€1,855.00")
        #expect(Money.format(cents: 0, locale: us) == "€0.00")
        #expect(Money.format(cents: 1, locale: us) == "€0.01")
        #expect(Money.format(cents: 100_000_000, locale: us) == "€1,000,000.00")
    }

    @Test("spoken form reads euros then cents")
    func spoken() {
        #expect(Money.spoken(cents: 21_258) == "212 euros 58")
        #expect(Money.spoken(cents: 500) == "5 euros")
        #expect(Money.spoken(cents: 105) == "1 euro 5")
    }
}
