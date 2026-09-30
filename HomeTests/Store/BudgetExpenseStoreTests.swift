import Testing
import Foundation
@testable import Casita

@Suite("Budget expense mutations") @MainActor struct BudgetExpenseStoreTests {
    typealias F = BudgetFixtures

    @Test("saving a new expense persists it and enqueues one outbox op")
    func saveNew() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        let expense = F.expense(4_537, by: F.guille)
        try await store.saveBudgetExpense(expense)
        #expect(store.budgetExpenses.map(\.id) == [expense.id])
        #expect(try await store._local?.pendingOps().map(\.tableName) == ["budget_expenses"])
        let reloaded = await F.makeStore(url: url)
        #expect(reloaded.budgetExpenses.map(\.amountCents) == [4_537])
    }

    @Test("saving an existing id replaces it instead of duplicating")
    func saveReplaces() async throws {
        let store = await F.makeStore()
        var expense = F.expense(1_000, by: F.guille)
        try await store.saveBudgetExpense(expense)
        expense.amountCents = 1_500
        try await store.saveBudgetExpense(expense)
        #expect(store.budgetExpenses.map(\.amountCents) == [1_500])
    }

    @Test("an invalid amount throws and writes nothing")
    func invalidWritesNothing() async throws {
        let store = await F.makeStore()
        await #expect(throws: BudgetValidationError.invalidAmount) {
            try await store.saveBudgetExpense(F.expense(0, by: F.guille))
        }
        await #expect(throws: BudgetValidationError.amountTooLarge) {
            try await store.saveBudgetExpense(F.expense(100_000_001, by: F.guille))
        }
        #expect(store.budgetExpenses.isEmpty)
        #expect(try await store._local?.pendingOps().isEmpty == true)
    }

    @Test("delete removes it from memory and from future hydrations")
    func delete() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        let expense = F.expense(1_000, by: F.guille)
        try await store.saveBudgetExpense(expense)
        try await store.deleteBudgetExpense(expense)
        #expect(store.budgetExpenses.isEmpty)
        #expect(await F.makeStore(url: url).budgetExpenses.isEmpty)
    }

    @Test("a saved expense moves the settlement")
    func settlementUpdates() async throws {
        let store = await F.makeStore()
        store.budgetMembers = [F.guille, F.lu]
        store.budgetCategories = [F.food]
        try await store.saveBudgetExpense(F.expense(1_000, by: F.guille))
        let s = store.budgetSummary(for: F.november, today: F.date(2026, 11, 15), calendar: F.calendar)
        #expect(s.settlement == [Transfer(fromMemberId: F.lu.id, toMemberId: F.guille.id, amountCents: 500)])
    }
}
