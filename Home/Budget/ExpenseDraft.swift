import Foundation

nonisolated struct ExpenseDraft: Identifiable, Equatable {
    static let lastPayerKey = "budget.lastPayerId"

    let id: UUID
    let isNew: Bool
    var recurringId: UUID?
    var amountText: String
    var categoryId: UUID?
    var payerId: UUID?
    var date: Date
    var name: String

    var title: String {
        if !isNew { return "Edit expense" }
        return recurringId == nil ? "New expense" : "Confirm bill"
    }

    init(expense: BudgetExpense) {
        id = expense.id
        isNew = false
        recurringId = expense.recurringId
        amountText = Money.editText(cents: expense.amountCents)
        categoryId = expense.categoryId
        payerId = expense.payerId
        date = expense.date
        name = expense.name
    }

    init(payerId: UUID?, date: Date) {
        id = UUID()
        isNew = true
        recurringId = nil
        amountText = ""
        categoryId = nil
        self.payerId = payerId
        self.date = date
        name = ""
    }

    init(confirming bill: RecurringExpense, month: BudgetMonth, calendar: Calendar) {
        id = BudgetIDs.recurringExpense(recurringId: bill.id, month: month)
        isNew = true
        recurringId = bill.id
        amountText = Money.editText(cents: bill.amountCents)
        categoryId = bill.categoryId
        payerId = bill.payerId
        date = month.date(day: bill.dayOfMonth, calendar: calendar)
        name = bill.name
    }

    func makeExpense() throws -> BudgetExpense {
        guard let cents = Money.parseCents(amountText) else { throw BudgetValidationError.invalidAmount }
        try BudgetValidation.amount(cents)
        guard let categoryId else { throw BudgetValidationError.missingCategory }
        guard let payerId else { throw BudgetValidationError.missingPayer }
        return BudgetExpense(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                             amountCents: cents, categoryId: categoryId, payerId: payerId,
                             date: date, recurringId: recurringId)
    }

    static func categoriesByUsage(_ categories: [BudgetCategory], expenses: [BudgetExpense],
                                  keeping selectedId: UUID?) -> [BudgetCategory] {
        let counts = Dictionary(grouping: expenses.filter { $0.deletedAt == nil }, by: \.categoryId)
            .mapValues(\.count)
        return categories
            .filter { $0.deletedAt == nil && (!$0.archived || $0.id == selectedId) }
            .sorted { a, b in
                let ca = counts[a.id] ?? 0, cb = counts[b.id] ?? 0
                return ca != cb ? ca > cb : (a.sortOrder, a.name) < (b.sortOrder, b.name)
            }
    }

    static func defaultPayer(stored: String, members: [BudgetMember]) -> UUID? {
        if let id = UUID(uuidString: stored), members.contains(where: { $0.id == id }) { return id }
        return members.first?.id
    }
}
