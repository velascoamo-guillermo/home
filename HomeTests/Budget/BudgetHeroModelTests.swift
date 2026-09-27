import Testing
import Foundation
@testable import Casita

@Suite("Budget hero model") @MainActor struct BudgetHeroModelTests {
    typealias F = BudgetFixtures
    private let us = Locale(identifier: "en_US")
    private let everything = BudgetCategory(name: "Everything", estimateCents: 185_500, sortOrder: 0)

    private func summary(incomes: [BudgetIncome] = [], expenses: [BudgetExpense]) -> MonthSummary {
        F.calculator(categories: [everything], incomes: incomes, expenses: expenses)
            .summary(for: F.november, today: F.date(2026, 11, 15))
    }

    private func summary(members: [BudgetMember], incomes: [BudgetIncome] = [], expenses: [BudgetExpense]) -> MonthSummary {
        F.calculator(members: members, categories: [everything], incomes: incomes, expenses: expenses)
            .summary(for: F.november, today: F.date(2026, 11, 15))
    }

    @Test("empty month is All square")
    func allSquare() {
        let model = BudgetHeroModel(summary: summary(expenses: []), locale: us)
        #expect(model.isAllSquare)
        #expect(model.lines.isEmpty)
        #expect(model.accessibilityLabel == "All square")
        #expect(model.remainingLine == "Remaining €1,855.00 of €1,855.00")
    }

    @Test("one transfer shows debtor → creditor, amount, and a spoken label")
    func oneTransfer() {
        let s = summary(expenses: [F.expense(42_516, by: F.guille, in: everything)])
        let model = BudgetHeroModel(summary: s, locale: us)
        #expect(model.lines == [BudgetHeroModel.Line(title: "Lu → Guille", amountText: "€212.58",
                                                     accessibilityLabel: "Lu owes Guille 212 euros 58")])
        #expect(model.accessibilityLabel == "Lu owes Guille 212 euros 58")
        #expect(model.ratioLine == "Guille 50% · Lu 50%")
        #expect(model.remainingLine == "Remaining €1,429.84 of €1,855.00")
    }

    @Test("ratio line follows income and omits former members")
    func ratioLine() {
        let ghost = BudgetMember(name: "Ghost", sortOrder: 9)
        let s = summary(incomes: [F.income(380_000, for: F.guille), F.income(100_000, for: F.lu)],
                        expenses: [F.expense(100, by: ghost, in: everything)])
        #expect(BudgetHeroModel(summary: s, locale: us).ratioLine == "Guille 79% · Lu 21%")
    }

    @Test("remaining line shows negative amount when over budget")
    func overBudgetRemaining() {
        // Expenses exceed estimate (200,000 > 185,500)
        let s = summary(expenses: [F.expense(200_000, by: F.guille, in: everything)])
        let model = BudgetHeroModel(summary: s, locale: us)
        // remainingCents = estimate - total = 185_500 - 200_000 = -14_500
        #expect(model.remainingLine == "Remaining -€145.00 of €1,855.00")
    }

    @Test("two settlement transfers with three members")
    func multipleTransfers() {
        let third = BudgetMember(name: "Third", sortOrder: 2)
        let s = summary(members: [F.guille, F.lu, third],
                       expenses: [F.expense(100, by: F.guille, in: everything)])
        let model = BudgetHeroModel(summary: s, locale: us)
        #expect(!model.isAllSquare)
        #expect(model.lines.count == 2)

        // Verify member balances: with 100¢ paid by Guille and equal weights,
        // largest-remainder apportionment gives shares 34/33/33.
        // Balances: Guille +66, Lu -33, Third -33
        #expect(s.members[0].balanceCents == 66)  // Guille
        #expect(s.members[1].balanceCents == -33) // Lu
        #expect(s.members[2].balanceCents == -33) // Third

        // Verify settlement transfers: Lu and Third each owe Guille 33¢
        #expect(model.lines == [
            BudgetHeroModel.Line(title: "Lu → Guille", amountText: "€0.33",
                                accessibilityLabel: "Lu owes Guille 0 euros 33"),
            BudgetHeroModel.Line(title: "Third → Guille", amountText: "€0.33",
                                accessibilityLabel: "Third owes Guille 0 euros 33")
        ])

        // Verify accessibility label contains both transfers
        #expect(model.accessibilityLabel.contains("Lu owes Guille"))
        #expect(model.accessibilityLabel.contains("Third owes Guille"))
    }
}
