import Testing
import Foundation
@testable import Casita

@Suite("Store restore") @MainActor struct StoreRestoreTests {
    typealias F = BudgetFixtures

    @Test("a restored task is back in memory, survives a reload and is queued for upload")
    func restoreTask() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        let task = HouseholdTask(title: "Bleed radiators", intervalDays: 365, nextDueDate: .now)
        try await store.addTask(task)
        try await store.deleteTask(task)
        try await store.restoreTask(task)
        #expect(store.householdTasks.map(\.id) == [task.id])
        #expect(await F.makeStore(url: url).householdTasks.map(\.id) == [task.id])
        let last = try #require(try await store._local?.pendingOps().last)
        #expect(last.tableName == HouseholdTask.tableName)
        #expect(last.kind == .update)
    }

    @Test("restoring stamps a newer updated_at than the delete so it wins last-write-wins")
    func restoreIsNewer() async throws {
        let store = await F.makeStore()
        let task = HouseholdTask(title: "Bleed radiators", intervalDays: 365, nextDueDate: .now,
                                 updatedAt: Date(timeIntervalSince1970: 0))
        try await store.addTask(task)
        try await store.deleteTask(task)
        let deletedAt = Date.now
        try await store.restoreTask(task)
        let restored = try #require(store.householdTasks.first)
        #expect(restored.updatedAt >= deletedAt)
        #expect(restored.deletedAt == nil)
    }

    @Test("restoring twice keeps a single row")
    func restoreIdempotent() async throws {
        let store = await F.makeStore()
        let task = HouseholdTask(title: "Bleed radiators", intervalDays: 365, nextDueDate: .now)
        try await store.addTask(task)
        try await store.restoreTask(task)
        try await store.restoreTask(task)
        #expect(store.householdTasks.count == 1)
    }

    @Test("restoring a product relinks the tasks that pointed at it")
    func restoreProductRelinks() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        let filters = StockProduct(name: "Filters", level: .medium)
        var task = HouseholdTask(title: "Change filter", intervalDays: 30, nextDueDate: .now)
        task.productId = filters.id
        try await store.addProduct(filters)
        try await store.addTask(task)
        try await store.deleteProduct(filters)
        #expect(store.householdTasks.first?.productId == nil)
        try await store.restoreProduct(filters, relinking: [task.id])
        #expect(store.stockProducts.map(\.id) == [filters.id])
        #expect(store.householdTasks.first?.productId == filters.id)
        let reloaded = await F.makeStore(url: url)
        #expect(reloaded.stockProducts.map(\.id) == [filters.id])
        #expect(reloaded.householdTasks.first?.productId == filters.id)
    }

    @Test("restoring a product does not override a task already relinked elsewhere")
    func restoreProductDoesNotOverrideRelink() async throws {
        let store = await F.makeStore()
        let filters = StockProduct(name: "Filters", level: .medium)
        let newFilters = StockProduct(name: "New Filters", level: .full)
        var task = HouseholdTask(title: "Change filter", intervalDays: 30, nextDueDate: .now)
        task.productId = filters.id
        try await store.addProduct(filters)
        try await store.addProduct(newFilters)
        try await store.addTask(task)
        try await store.deleteProduct(filters)
        var relinked = task
        relinked.productId = newFilters.id
        try await store.updateTask(relinked)
        try await store.restoreProduct(filters, relinking: [task.id])
        #expect(store.householdTasks.first?.productId == newFilters.id)
    }

    @Test("saving a deleted expense again restores it")
    func expenseRestoresThroughSave() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        let expense = F.expense(1_250, by: F.guille)
        try await store.saveBudgetExpense(expense)
        try await store.deleteBudgetExpense(expense)
        try await store.saveBudgetExpense(expense)
        #expect(await F.makeStore(url: url).budgetExpenses.map(\.id) == [expense.id])
    }
}
