import Foundation
@testable import Casita

enum BudgetFixtures {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c
    }()

    static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    static let guille = BudgetMember(name: "Guille", sortOrder: 0)
    static let lu = BudgetMember(name: "Lu", sortOrder: 1)
    static let rent = BudgetCategory(name: "Alquiler", estimateCents: 90_500, sortOrder: 0)
    static let food = BudgetCategory(name: "Supermarket", estimateCents: 35_000, sortOrder: 1)
    static let november = BudgetMonth(year: 2026, month: 11)

    static func expense(_ cents: Int, by payer: BudgetMember, in category: BudgetCategory = food,
                        on day: Date = BudgetFixtures.date(2026, 11, 10),
                        recurringId: UUID? = nil) -> BudgetExpense {
        BudgetExpense(amountCents: cents, categoryId: category.id, payerId: payer.id,
                      date: day, recurringId: recurringId)
    }

    static func income(_ cents: Int, for member: BudgetMember, month: String = "2026-11") -> BudgetIncome {
        BudgetIncome(memberId: member.id, month: month, amountCents: cents)
    }

    static func calculator(members: [BudgetMember] = [guille, lu],
                           categories: [BudgetCategory] = [rent, food],
                           incomes: [BudgetIncome] = [],
                           recurring: [RecurringExpense] = [],
                           expenses: [BudgetExpense] = []) -> BudgetCalculator {
        BudgetCalculator(members: members, categories: categories, incomes: incomes,
                         recurring: recurring, expenses: expenses, calendar: calendar)
    }
}
