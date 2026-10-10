import Foundation

nonisolated struct CategoryLine: Identifiable, Equatable, Sendable {
    let category: BudgetCategory
    let actualCents: Int

    var id: UUID { category.id }
    var estimateCents: Int { category.estimateCents }
    var isArchived: Bool { category.archived }
    var isOverBudget: Bool { actualCents > estimateCents }
}
