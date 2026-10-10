import Foundation

nonisolated struct MonthSummary: Equatable, Sendable {
    let month: BudgetMonth
    let totalCents: Int
    let estimateCents: Int
    let remainingCents: Int
    let categories: [CategoryLine]
    let members: [MemberLine]
    let settlement: [Transfer]
    let pendingRecurring: [RecurringExpense]

    func memberName(_ id: UUID) -> String {
        members.first { $0.id == id }?.name ?? BudgetCalculator.formerMemberName
    }
}
