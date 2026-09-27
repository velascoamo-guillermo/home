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

    // MARK: - Members & incomes

    func addBudgetMember(name: String) async throws {
        try BudgetValidation.name(name)
        let member = BudgetMember(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                  sortOrder: (budgetMembers.map(\.sortOrder).max() ?? -1) + 1)
        try await _local?.upsert([member], enqueue: true)
        budgetMembers.append(member)
        await _sync?.sync(tables: [BudgetMember.tableName])
    }

    func renameBudgetMember(_ member: BudgetMember, to name: String) async throws {
        try BudgetValidation.name(name)
        var m = member
        m.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        m.updatedAt = .now
        try await _local?.upsert([m], enqueue: true)
        if let i = budgetMembers.firstIndex(where: { $0.id == m.id }) { budgetMembers[i] = m }
        await _sync?.sync(tables: [BudgetMember.tableName])
    }

    func deleteBudgetMember(_ member: BudgetMember) async throws {
        guard budgetMembers.count > 1 else { throw BudgetValidationError.lastMember }
        try await _local?.softDelete(member, enqueue: true)
        budgetMembers.removeAll { $0.id == member.id }
        await _sync?.sync(tables: [BudgetMember.tableName])
    }

    func setBudgetIncome(memberId: UUID, month: BudgetMonth, amountCents: Int) async throws {
        try BudgetValidation.nonNegativeAmount(amountCents)
        let income = BudgetIncome(id: BudgetIDs.income(memberId: memberId, month: month),
                                  memberId: memberId, month: month.key, amountCents: amountCents)
        try await _local?.upsert([income], enqueue: true)
        if let i = budgetIncomes.firstIndex(where: { $0.id == income.id }) {
            budgetIncomes[i] = income
        } else {
            budgetIncomes.append(income)
        }
        await _sync?.sync(tables: [BudgetIncome.tableName])
    }

    // MARK: - Categories

    func saveBudgetCategory(_ category: BudgetCategory) async throws {
        try BudgetValidation.name(category.name)
        try BudgetValidation.nonNegativeAmount(category.estimateCents)
        var c = category
        c.name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        c.updatedAt = .now
        try await _local?.upsert([c], enqueue: true)
        if let i = budgetCategories.firstIndex(where: { $0.id == c.id }) {
            budgetCategories[i] = c
        } else {
            budgetCategories.append(c)
        }
        budgetCategories.sort { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
        await _sync?.sync(tables: [BudgetCategory.tableName])
    }

    func setBudgetCategoryArchived(_ category: BudgetCategory, archived: Bool) async throws {
        var c = category
        c.archived = archived
        try await saveBudgetCategory(c)
    }

    func deleteBudgetCategory(_ category: BudgetCategory) async throws {
        let inUse = budgetExpenses.contains { $0.categoryId == category.id }
            || recurringExpenses.contains { $0.categoryId == category.id }
        guard !inUse else { throw BudgetValidationError.categoryInUse }
        try await _local?.softDelete(category, enqueue: true)
        budgetCategories.removeAll { $0.id == category.id }
        await _sync?.sync(tables: [BudgetCategory.tableName])
    }

    /// Renumbers the FULL live category list: `ordered` first (in the given order), then any
    /// live categories not included (e.g. archived, when only the active subset was reordered)
    /// keeping their existing relative order. This avoids `sortOrder` collisions between the
    /// reordered subset and categories the caller didn't pass.
    func reorderBudgetCategories(_ ordered: [BudgetCategory]) async throws {
        let orderedIds = Set(ordered.map(\.id))
        let rest = budgetCategories.filter { !orderedIds.contains($0.id) }
        let combined = ordered + rest
        let changed = combined.enumerated().compactMap { index, category -> BudgetCategory? in
            guard category.sortOrder != index else { return nil }
            var c = category
            c.sortOrder = index
            c.updatedAt = .now
            return c
        }
        guard !changed.isEmpty else { return }
        try await _local?.upsert(changed, enqueue: true)
        for c in changed {
            if let i = budgetCategories.firstIndex(where: { $0.id == c.id }) { budgetCategories[i] = c }
        }
        budgetCategories.sort { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
        await _sync?.sync(tables: [BudgetCategory.tableName])
    }
}
