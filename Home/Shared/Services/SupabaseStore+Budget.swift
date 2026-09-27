import Foundation

extension SupabaseStore {

    func budgetSummary(for month: BudgetMonth, today: Date = .now,
                       calendar: Calendar = .current) -> MonthSummary {
        BudgetCalculator(members: budgetMembers, categories: budgetCategories,
                         incomes: budgetIncomes, recurring: recurringExpenses,
                         expenses: budgetExpenses, calendar: calendar)
            .summary(for: month, today: today)
    }

    // MARK: - Seeding

    /// Seeds only once the remote has been read, so a fresh install never writes defaults
    /// over a household that already exists on another device.
    func seedBudgetIfNeeded() async {
        guard let sync = _sync, _local != nil,
              budgetMembers.isEmpty, budgetCategories.isEmpty else { return }
        guard await sync.hasPulled(BudgetMember.tableName),
              await sync.hasPulled(BudgetCategory.tableName) else { return }
        try? await seedBudgetDefaults()
    }

    func seedBudgetDefaults() async throws {
        let members = BudgetSeed.members()
        let categories = BudgetSeed.categories()
        try await _local?.upsert(members, enqueue: true)
        try await _local?.upsert(categories, enqueue: true)
        budgetMembers = members
        budgetCategories = categories
        await _sync?.sync(tables: [BudgetMember.tableName, BudgetCategory.tableName])
    }
}
