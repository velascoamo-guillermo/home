import Testing
import Foundation
@testable import Casita

@Suite("BudgetCalculator") @MainActor struct BudgetCalculatorTests {
    typealias F = BudgetFixtures
    private let today = F.date(2026, 11, 15)

    private func line(_ s: MonthSummary, _ m: BudgetMember) throws -> MemberLine {
        try #require(s.members.first { $0.id == m.id })
    }

    @Test("ratio comes from income: 3800 vs 1000 is 79% / 21%")
    func ratioFromIncome() throws {
        let s = F.calculator(incomes: [F.income(380_000, for: F.guille), F.income(100_000, for: F.lu)],
                             expenses: [F.expense(10_000, by: F.guille)])
            .summary(for: F.november, today: today)
        #expect(try line(s, F.guille).ratioPercent == 79)
        #expect(try line(s, F.lu).ratioPercent == 21)
    }

    @Test("shares are cent-exact and odd cents go to the largest remainder")
    func centExactShares() throws {
        // 10001 * 380000/480000 = 7917.458…, 10001 * 100000/480000 = 2083.541… → leftover cent to Lu.
        let s = F.calculator(incomes: [F.income(380_000, for: F.guille), F.income(100_000, for: F.lu)],
                             expenses: [F.expense(10_001, by: F.guille)])
            .summary(for: F.november, today: today)
        #expect(try line(s, F.guille).shareCents == 7_917)
        #expect(try line(s, F.lu).shareCents == 2_084)
        #expect(s.members.reduce(0) { $0 + $1.shareCents } == s.totalCents)
    }

    @Test("remainder ties go to the lower sort order")
    func tieBreak() {
        #expect(BudgetCalculator.split(101, weights: [1, 1], order: [0, 1]) == [51, 50])
        #expect(BudgetCalculator.split(101, weights: [1, 1], order: [1, 0]) == [50, 51])
        #expect(BudgetCalculator.split(0, weights: [3, 1], order: [0, 1]) == [0, 0])
        #expect(BudgetCalculator.split(100, weights: [], order: []) == [])
    }

    @Test("balance is paid minus share; savings is income minus share")
    func balancesAndSavings() throws {
        let s = F.calculator(incomes: [F.income(380_000, for: F.guille), F.income(100_000, for: F.lu)],
                             expenses: [F.expense(10_001, by: F.guille)])
            .summary(for: F.november, today: today)
        let g = try line(s, F.guille), l = try line(s, F.lu)
        #expect(g.paidCents == 10_001)
        #expect(g.balanceCents == 2_084)
        #expect(l.balanceCents == -2_084)
        #expect(g.savingsCents == 380_000 - 7_917)
        #expect(l.savingsCents == 100_000 - 2_084)
        #expect(s.settlement == [Transfer(fromMemberId: F.lu.id, toMemberId: F.guille.id, amountCents: 2_084)])
    }

    @Test("three members settle greedily: largest debtor pays largest creditor first")
    func threeMemberSettlement() {
        let ana = BudgetMember(name: "Ana", sortOrder: 2)
        // Equal (zero) incomes → equal split of 600 = 200 each. Balances: G +300, Lu -100, Ana -200.
        let s = F.calculator(members: [F.guille, F.lu, ana],
                             expenses: [F.expense(500, by: F.guille), F.expense(100, by: F.lu)])
            .summary(for: F.november, today: today)
        #expect(s.settlement == [
            Transfer(fromMemberId: ana.id, toMemberId: F.guille.id, amountCents: 200),
            Transfer(fromMemberId: F.lu.id, toMemberId: F.guille.id, amountCents: 100),
        ])
    }

    @Test("missing income carries over from the latest earlier month and is flagged")
    func incomeCarryOver() throws {
        let s = F.calculator(incomes: [F.income(300_000, for: F.guille, month: "2026-09"),
                                       F.income(320_000, for: F.guille, month: "2026-10"),
                                       F.income(100_000, for: F.lu)])
            .summary(for: F.november, today: today)
        #expect(try line(s, F.guille).incomeCents == 320_000)
        #expect(try line(s, F.guille).incomeCarriedOver)
        #expect(try !line(s, F.lu).incomeCarriedOver)
    }

    @Test("an explicit row in a later month is not used for an earlier month")
    func laterExplicitIncomeWins() throws {
        let incomes = [F.income(300_000, for: F.guille, month: "2026-10"),
                       F.income(999_000, for: F.guille, month: "2026-12")]
        let nov = F.calculator(incomes: incomes).summary(for: F.november, today: today)
        let dec = F.calculator(incomes: incomes).summary(for: F.november.next, today: today)
        #expect(try line(nov, F.guille).incomeCents == 300_000)
        #expect(try line(dec, F.guille).incomeCents == 999_000)
        #expect(try !line(dec, F.guille).incomeCarriedOver)
    }

    @Test("no income anywhere is 0 and the split is equal")
    func zeroTotalIncome() throws {
        let s = F.calculator(expenses: [F.expense(1_000, by: F.lu)]).summary(for: F.november, today: today)
        #expect(try line(s, F.guille).incomeCents == 0)
        #expect(try line(s, F.guille).ratioPercent == 50)
        #expect(try line(s, F.guille).shareCents == 500)
        #expect(s.settlement == [Transfer(fromMemberId: F.guille.id, toMemberId: F.lu.id, amountCents: 500)])
    }

    @Test("an empty month is all square with the full estimate remaining")
    func emptyMonth() {
        let s = F.calculator().summary(for: F.november, today: today)
        #expect(s.totalCents == 0)
        #expect(s.settlement.isEmpty)
        #expect(s.estimateCents == 125_500)
        #expect(s.remainingCents == 125_500)
        #expect(s.categories.map(\.actualCents) == [0, 0])
    }

    @Test("remaining goes negative when over the estimate")
    func overEstimate() {
        let s = F.calculator(categories: [F.food], expenses: [F.expense(40_000, by: F.guille)])
            .summary(for: F.november, today: today)
        #expect(s.remainingCents == -5_000)
        #expect(s.categories.first?.isOverBudget == true)
    }

    @Test("archived category: excluded from estimate, listed only when it has expenses")
    func archivedCategory() {
        var clothes = BudgetCategory(name: "Ropa", estimateCents: 4_000, sortOrder: 2)
        clothes.archived = true
        var unused = BudgetCategory(name: "Viejo", estimateCents: 1_000, sortOrder: 3)
        unused.archived = true
        let s = F.calculator(categories: [F.rent, F.food, clothes, unused],
                             expenses: [F.expense(2_500, by: F.lu, in: clothes)])
            .summary(for: F.november, today: today)
        #expect(s.estimateCents == 125_500)
        #expect(s.categories.map(\.category.name) == ["Alquiler", "Supermarket", "Ropa"])
        #expect(s.categories.last?.isArchived == true)
        #expect(s.categories.last?.actualCents == 2_500)
    }

    @Test("a payer who is no longer a member counts as Former member and balances still sum to zero")
    func formerMember() throws {
        let ghost = BudgetMember(name: "Ghost", sortOrder: 5)
        let s = F.calculator(expenses: [F.expense(1_000, by: ghost), F.expense(1_000, by: F.guille)])
            .summary(for: F.november, today: today)
        let former = try #require(s.members.first { $0.isFormer })
        #expect(former.id == ghost.id)
        #expect(former.name == "Former member")
        #expect(former.shareCents == 0)
        #expect(s.totalCents == 2_000)
        #expect(s.members.reduce(0) { $0 + $1.balanceCents } == 0)
        #expect(s.memberName(ghost.id) == "Former member")
        #expect(s.settlement == [Transfer(fromMemberId: F.lu.id, toMemberId: ghost.id, amountCents: 1_000)])
    }

    @Test("expenses belong to the month containing their date in the supplied calendar")
    func monthMembershipUsesCalendar() {
        let justAfterMidnight = F.date(2026, 12, 1, 0, 30)
        let s = F.calculator(expenses: [F.expense(700, by: F.guille, on: justAfterMidnight),
                                        F.expense(300, by: F.guille, on: F.date(2026, 11, 30, 23, 59))])
            .summary(for: F.november, today: today)
        #expect(s.totalCents == 300)
    }

    @Test("soft-deleted expenses are ignored")
    func deletedExpenseIgnored() {
        var gone = F.expense(5_000, by: F.guille)
        gone.deletedAt = .now
        let s = F.calculator(expenses: [gone]).summary(for: F.november, today: today)
        #expect(s.totalCents == 0)
    }

    private func bill(_ name: String, day: Int, active: Bool = true) -> RecurringExpense {
        RecurringExpense(name: name, amountCents: 2_000, categoryId: F.rent.id,
                         payerId: F.guille.id, dayOfMonth: day, active: active)
    }

    @Test("pending recurring: current month only up to today, past month all, future none")
    func pendingRecurring() {
        let early = bill("Internet", day: 10), late = bill("Luz", day: 20)
        let off = bill("Gym", day: 1, active: false)
        let calc = F.calculator(recurring: [late, early, off])
        #expect(calc.summary(for: F.november, today: today).pendingRecurring == [early])
        #expect(calc.summary(for: F.november.previous, today: today).pendingRecurring == [early, late])
        #expect(calc.summary(for: F.november.next, today: today).pendingRecurring.isEmpty)
    }

    @Test("a bill confirmed this month is no longer pending")
    func confirmedNotPending() {
        let internet = bill("Internet", day: 5)
        let s = F.calculator(recurring: [internet],
                             expenses: [F.expense(2_000, by: F.guille, recurringId: internet.id)])
            .summary(for: F.november, today: today)
        #expect(s.pendingRecurring.isEmpty)
    }
}
