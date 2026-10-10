import Testing
import Foundation
@testable import Casita

@Suite("Budget day groups") @MainActor struct BudgetDayGroupTests {
    typealias F = BudgetFixtures

    @Test("groups the month's live expenses by day, newest day and newest expense first")
    func groups() {
        let morning = F.expense(100, by: F.guille, on: F.date(2026, 11, 3, 10))
        let evening = F.expense(200, by: F.lu, on: F.date(2026, 11, 3, 18))
        let fifth = F.expense(300, by: F.lu, on: F.date(2026, 11, 5))
        let december = F.expense(400, by: F.lu, on: F.date(2026, 12, 1, 0, 30))
        var deleted = F.expense(500, by: F.lu, on: F.date(2026, 11, 5))
        deleted.deletedAt = .now
        let groups = BudgetDayGroup.groups([morning, fifth, december, evening, deleted],
                                           in: F.november, calendar: F.calendar)
        #expect(groups.map(\.day) == [F.calendar.startOfDay(for: F.date(2026, 11, 5)),
                                      F.calendar.startOfDay(for: F.date(2026, 11, 3))])
        #expect(groups.map { $0.expenses.map(\.amountCents) } == [[300], [200, 100]])
    }
}
