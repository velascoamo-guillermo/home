import Foundation

/// Form state for a recurring bill. The id is fixed when the form opens so repeated
/// saves of a new bill upsert one row instead of minting a fresh bill each time.
nonisolated struct RecurringBillDraft: Equatable {
    let id: UUID
    let isNew: Bool
    var name: String
    var amountText: String
    var categoryId: UUID?
    var payerId: UUID?
    var dayOfMonth: Int
    var active: Bool

    init(existing: RecurringExpense?) {
        id = existing?.id ?? UUID()
        isNew = existing == nil
        name = existing?.name ?? ""
        amountText = existing.map { Money.editText(cents: $0.amountCents) } ?? ""
        categoryId = existing?.categoryId
        payerId = existing?.payerId
        dayOfMonth = existing?.dayOfMonth ?? 1
        active = existing?.active ?? true
    }

    func makeBill() throws -> RecurringExpense {
        try BudgetValidation.name(name)
        guard let cents = Money.parseCents(amountText) else { throw BudgetValidationError.invalidAmount }
        try BudgetValidation.amount(cents)
        guard let categoryId else { throw BudgetValidationError.missingCategory }
        guard let payerId else { throw BudgetValidationError.missingPayer }
        try BudgetValidation.dayOfMonth(dayOfMonth)
        return RecurringExpense(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                amountCents: cents, categoryId: categoryId, payerId: payerId,
                                dayOfMonth: dayOfMonth, active: active)
    }
}
