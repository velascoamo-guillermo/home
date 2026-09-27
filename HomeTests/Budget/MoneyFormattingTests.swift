import Testing
import Foundation
@testable import Casita

@Suite("Money formatting") @MainActor struct MoneyFormattingTests {
    private let us = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_ES")

    @Test("formats cents as EUR without floating point drift")
    func format() {
        #expect(Money.format(cents: 21_258, locale: us) == "€212.58")
        #expect(Money.format(cents: 185_500, locale: us) == "€1,855.00")
        #expect(Money.format(cents: 0, locale: us) == "€0.00")
        #expect(Money.format(cents: 1, locale: us) == "€0.01")
        #expect(Money.format(cents: 100_000_000, locale: us) == "€1,000,000.00")
    }

    @Test("formats negative cents with correct sign in en_US and es_ES")
    func negativeFormat() {
        // en_US: -50.00 EUR typically formats as "-€50.00"
        let negativeUS = Money.format(cents: -5_000, locale: us)
        #expect(negativeUS.contains("-"))
        #expect(negativeUS.contains("50.00"))

        // es_ES: -50.00 EUR typically formats as "-50,00 €"
        let negativeES = Money.format(cents: -5_000, locale: es)
        #expect(negativeES.contains("-"))
        #expect(negativeES.contains("50,00"))
    }

    @Test("spoken form reads euros then cents")
    func spoken() {
        #expect(Money.spoken(cents: 21_258) == "212 euros 58")
        #expect(Money.spoken(cents: 500) == "5 euros")
        #expect(Money.spoken(cents: 105) == "1 euro 5")
    }
}
