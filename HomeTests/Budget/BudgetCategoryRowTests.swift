import Testing
import Foundation
@testable import Casita

@Suite("Budget category row") @MainActor struct BudgetCategoryRowTests {
    private let us = Locale(identifier: "en_US")
    private let luz = BudgetCategory(name: "Luz", estimateCents: 11_000)

    @Test("accessibility value exposes actual and estimate")
    func underBudget() {
        let line = CategoryLine(category: luz, actualCents: 5_000)
        #expect(BudgetCategoryRow.accessibilityValue(for: line, locale: us) == "€50.00 of €110.00")
    }

    @Test("accessibility value says over budget")
    func overBudget() {
        let line = CategoryLine(category: luz, actualCents: 12_000)
        #expect(BudgetCategoryRow.accessibilityValue(for: line, locale: us) == "€120.00 of €110.00, over budget")
    }
}
