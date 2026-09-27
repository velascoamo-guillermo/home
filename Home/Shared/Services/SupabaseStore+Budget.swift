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
    /// over a household that already exists on another device. Emptiness is re-checked
    /// against on-disk rows (not the in-memory arrays, which can be stale when the
    /// reconnect observer races `loadAll`'s hydrate, or when an earlier table throws
    /// inside `hydrate`). The in-flight flag is set synchronously before the first
    /// `await` so concurrent callers (`loadAll`, `refreshFromLocal`, the reconnect
    /// observer) never both seed; it clears on any exit so a failed or not-yet-eligible
    /// attempt can still retry later, while a completed attempt (seeded, or found
    /// existing rows) is marked done for good.
    func seedBudgetIfNeeded() async {
        guard !seedCompleted, !seedInFlight else { return }
        seedInFlight = true
        defer { seedInFlight = false }

        guard let sync = _sync, let local = _local else { return }
        guard await sync.hasPulled(BudgetMember.tableName),
              await sync.hasPulled(BudgetCategory.tableName) else { return }
        guard let localMembers = try? await local.fetchAll(BudgetMember.self),
              let localCategories = try? await local.fetchAll(BudgetCategory.self) else { return }
        guard localMembers.isEmpty, localCategories.isEmpty else {
            seedCompleted = true
            return
        }
        do {
            try await seedBudgetDefaults()
            seedCompleted = true
        } catch {
            // leave seedCompleted false so a later call can retry
        }
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

    // MARK: - Expenses

    func saveBudgetExpense(_ expense: BudgetExpense) async throws {
        try BudgetValidation.amount(expense.amountCents)
        var e = expense
        e.updatedAt = .now
        e.deletedAt = nil
        try await _local?.upsert([e], enqueue: true)
        if let i = budgetExpenses.firstIndex(where: { $0.id == e.id }) {
            budgetExpenses[i] = e
        } else {
            budgetExpenses.append(e)
        }
        await _sync?.sync(tables: [BudgetExpense.tableName])
    }

    func deleteBudgetExpense(_ expense: BudgetExpense) async throws {
        try await _local?.softDelete(expense, enqueue: true)
        budgetExpenses.removeAll { $0.id == expense.id }
        await _sync?.sync(tables: [BudgetExpense.tableName])
    }
}
