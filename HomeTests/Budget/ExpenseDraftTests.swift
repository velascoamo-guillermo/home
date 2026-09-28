import Testing
import Foundation
@testable import Casita

@Suite("Expense draft") @MainActor struct ExpenseDraftTests {
    typealias F = BudgetFixtures

    private func draft(_ amount: String) -> ExpenseDraft {
        var d = ExpenseDraft(payerId: F.guille.id, date: F.date(2026, 11, 3))
        d.amountText = amount
        d.categoryId = F.food.id
        return d
    }

    @Test("builds an expense with exact cents and trimmed name")
    func makesExpense() throws {
        var d = draft("45,37")
        d.name = "  Mercadona "
        let e = try d.makeExpense()
        #expect(e.id == d.id)
        #expect(e.amountCents == 4_537)
        #expect(e.name == "Mercadona")
        #expect(e.categoryId == F.food.id)
        #expect(e.payerId == F.guille.id)
        #expect(e.recurringId == nil)
    }

    @Test("rejects zero, garbage and amounts over €1,000,000.00")
    func amountErrors() {
        #expect(throws: BudgetValidationError.invalidAmount) { try draft("0").makeExpense() }
        #expect(throws: BudgetValidationError.invalidAmount) { try draft("abc").makeExpense() }
        #expect(throws: BudgetValidationError.amountTooLarge) { try draft("1000000,01").makeExpense() }
        #expect(throws: Never.self) { try draft("1000000").makeExpense() }
    }

    @Test("requires a category and a payer")
    func missingFields() {
        var noCategory = draft("5")
        noCategory.categoryId = nil
        #expect(throws: BudgetValidationError.missingCategory) { try noCategory.makeExpense() }
        var noPayer = draft("5")
        noPayer.payerId = nil
        #expect(throws: BudgetValidationError.missingPayer) { try noPayer.makeExpense() }
    }

    @Test("editing keeps the expense id and pre-fills every field")
    func editing() {
        var e = F.expense(1_205, by: F.lu, on: F.date(2026, 11, 4))
        e.name = "Farmacia"
        let d = ExpenseDraft(expense: e)
        #expect(!d.isNew)
        #expect(d.id == e.id)
        #expect(d.amountText == "12.05")
        #expect(d.payerId == F.lu.id)
        #expect(d.name == "Farmacia")
        #expect(d.title == "Edit expense")
        #expect(ExpenseDraft(payerId: nil, date: .now).title == "New expense")
    }

    @Test("categories ordered by usage count, then sort order; archived hidden unless selected")
    func categoryOrder() {
        var archived = BudgetCategory(name: "Viejo", sortOrder: 5)
        archived.archived = true
        let expenses = [F.expense(1, by: F.lu, in: F.food), F.expense(1, by: F.lu, in: F.food),
                        F.expense(1, by: F.lu, in: F.rent)]
        let all = [F.rent, F.food, archived]
        #expect(ExpenseDraft.categoriesByUsage(all, expenses: expenses, keeping: nil).map(\.name)
                == ["Supermarket", "Alquiler"])
        #expect(ExpenseDraft.categoriesByUsage(all, expenses: [], keeping: nil).map(\.name)
                == ["Alquiler", "Supermarket"])
        #expect(ExpenseDraft.categoriesByUsage(all, expenses: [], keeping: archived.id).map(\.name)
                == ["Alquiler", "Supermarket", "Viejo"])
    }

    @Test("default payer is the stored last payer when still a member, else the first member")
    func defaultPayer() {
        let members = [F.guille, F.lu]
        #expect(ExpenseDraft.defaultPayer(stored: F.lu.id.uuidString, members: members) == F.lu.id)
        #expect(ExpenseDraft.defaultPayer(stored: UUID().uuidString, members: members) == F.guille.id)
        #expect(ExpenseDraft.defaultPayer(stored: "", members: members) == F.guille.id)
        #expect(ExpenseDraft.defaultPayer(stored: "", members: []) == nil)
    }

    @Test("confirming a bill pre-fills it with a deterministic id for that month")
    func confirming() throws {
        let bill = RecurringExpense(name: "Internet", amountCents: 5_000, categoryId: F.rent.id,
                                    payerId: F.lu.id, dayOfMonth: 5)
        let d = ExpenseDraft(confirming: bill, month: F.november, calendar: F.calendar)
        #expect(d.id == BudgetIDs.recurringExpense(recurringId: bill.id, month: F.november))
        #expect(d.isNew)
        #expect(d.title == "Confirm bill")
        #expect(d.amountText == "50.00")
        #expect(d.categoryId == F.rent.id)
        #expect(d.payerId == F.lu.id)
        #expect(d.name == "Internet")
        #expect(F.calendar.component(.day, from: d.date) == 5)
        #expect(BudgetMonth(date: d.date, calendar: F.calendar) == F.november)
        #expect(try d.makeExpense().recurringId == bill.id)
    }

    @Test("a new expense defaults to today in the current month, else to the same day inside the viewed month")
    func defaultDate() {
        let today = F.date(2026, 11, 30, 9)
        #expect(ExpenseDraft.defaultDate(viewing: F.november, today: today, calendar: F.calendar) == today)
        let october = ExpenseDraft.defaultDate(viewing: F.november.previous, today: today, calendar: F.calendar)
        #expect(october == F.date(2026, 10, 28))
        #expect(F.november.previous.contains(october, calendar: F.calendar))
        let early = ExpenseDraft.defaultDate(viewing: F.november.next, today: F.date(2026, 11, 3), calendar: F.calendar)
        #expect(early == F.date(2026, 12, 3))
    }
}
