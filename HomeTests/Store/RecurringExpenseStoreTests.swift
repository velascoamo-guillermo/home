import Testing
import Foundation
@testable import Casita

@Suite("Recurring bill mutations") @MainActor struct RecurringExpenseStoreTests {
    typealias F = BudgetFixtures
    private let today = BudgetFixtures.date(2026, 11, 15)

    private func seeded(url: URL = BudgetFixtures.tempURL()) async throws -> SupabaseStore {
        let store = await F.makeStore(url: url)
        try await store.seedBudgetDefaults()
        return store
    }

    private func bill(_ store: SupabaseStore, day: Int = 1, name: String = "Internet",
                      cents: Int = 2_000) throws -> RecurringExpense {
        RecurringExpense(name: name, amountCents: cents,
                         categoryId: try #require(store.budgetCategories.first).id,
                         payerId: try #require(store.budgetMembers.first).id, dayOfMonth: day)
    }

    private func pending(_ store: SupabaseStore) -> [RecurringExpense] {
        store.budgetSummary(for: F.november, today: today, calendar: F.calendar).pendingRecurring
    }

    @Test("bills validate day 1...28, name and amount")
    func validation() async throws {
        let store = try await seeded()
        await #expect(throws: BudgetValidationError.dayOutOfRange) { try await store.saveRecurringExpense(try bill(store, day: 0)) }
        await #expect(throws: BudgetValidationError.dayOutOfRange) { try await store.saveRecurringExpense(try bill(store, day: 29)) }
        await #expect(throws: BudgetValidationError.emptyName) { try await store.saveRecurringExpense(try bill(store, name: " ")) }
        await #expect(throws: BudgetValidationError.invalidAmount) { try await store.saveRecurringExpense(try bill(store, cents: 0)) }
        #expect(store.recurringExpenses.isEmpty)
        try await store.saveRecurringExpense(try bill(store, day: 28))
        #expect(store.recurringExpenses.count == 1)
    }

    @Test("confirming a due bill removes it from pending")
    func confirmClearsPending() async throws {
        let store = try await seeded()
        let internet = try bill(store)
        try await store.saveRecurringExpense(internet)
        #expect(pending(store).map(\.id) == [internet.id])
        let draft = ExpenseDraft(confirming: internet, month: F.november, calendar: F.calendar)
        try await store.saveBudgetExpense(try draft.makeExpense())
        #expect(pending(store).isEmpty)
        #expect(store.budgetExpenses.first?.id == BudgetIDs.recurringExpense(recurringId: internet.id, month: F.november))
    }

    @Test("deleting a confirmed bill makes it pending again; re-confirming keeps one row")
    func deleteThenReconfirmSingleRow() async throws {
        let url = F.tempURL()
        let store = try await seeded(url: url)
        let internet = try bill(store)
        try await store.saveRecurringExpense(internet)
        let first = try ExpenseDraft(confirming: internet, month: F.november, calendar: F.calendar).makeExpense()
        try await store.saveBudgetExpense(first)
        try await store.deleteBudgetExpense(first)
        #expect(pending(store).map(\.id) == [internet.id])
        var again = ExpenseDraft(confirming: internet, month: F.november, calendar: F.calendar)
        again.amountText = "21.50"
        try await store.saveBudgetExpense(try again.makeExpense())
        #expect(store.budgetExpenses.filter { $0.recurringId == internet.id }.map(\.amountCents) == [2_150])
        let reloaded = await F.makeStore(url: url)
        #expect(reloaded.budgetExpenses.filter { $0.recurringId == internet.id }.count == 1)
        #expect(pending(store).isEmpty)
    }

    @Test("inactive and deleted bills are never pending")
    func inactiveAndDeleted() async throws {
        let store = try await seeded()
        var paused = try bill(store, name: "Gym")
        paused.active = false
        let gone = try bill(store, name: "Old")
        try await store.saveRecurringExpense(paused)
        try await store.saveRecurringExpense(gone)
        try await store.deleteRecurringExpense(gone)
        #expect(pending(store).isEmpty)
        #expect(store.recurringExpenses.map(\.name) == ["Gym"])
    }
}
