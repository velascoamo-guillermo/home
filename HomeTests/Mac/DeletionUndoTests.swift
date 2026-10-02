#if os(macOS)
import Testing
import Foundation
@testable import Casita

@MainActor final class UndoProbe {
    var calls: [String] = []
}

@Suite("DeletionUndo") @MainActor struct DeletionUndoTests {
    typealias F = BudgetFixtures

    private func manager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    @Test("undo restores, redo deletes again, and both stay available with a specific name")
    func undoRedo() async throws {
        let manager = manager()
        let probe = UndoProbe()
        manager.beginUndoGrouping()
        DeletionUndo.register(on: manager, named: "Delete Task",
                              undo: { probe.calls.append("restore") },
                              redo: { probe.calls.append("delete") })
        manager.endUndoGrouping()
        #expect(manager.undoMenuItemTitle == "Undo Delete Task")

        manager.undo()
        try await F.waitUntil { probe.calls == ["restore"] }
        #expect(probe.calls == ["restore"])
        #expect(manager.redoMenuItemTitle == "Redo Delete Task")

        manager.redo()
        try await F.waitUntil { probe.calls == ["restore", "delete"] }
        #expect(probe.calls == ["restore", "delete"])
        #expect(manager.canUndo)
    }

    @Test("deleting a task registers an undo that brings it back from disk")
    func taskUndo() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        let task = HouseholdTask(title: "Descale kettle", intervalDays: 30, nextDueDate: .now)
        try await store.addTask(task)
        let manager = manager()
        manager.beginUndoGrouping()
        try await store.deleteTask(task, undoManager: manager)
        manager.endUndoGrouping()
        #expect(store.householdTasks.isEmpty)
        manager.undo()
        try await F.waitUntil { store.householdTasks.count == 1 }
        #expect(await F.makeStore(url: url).householdTasks.map(\.id) == [task.id])
    }

    @Test("undoing a product deletion relinks its tasks")
    func productUndo() async throws {
        let store = await F.makeStore()
        let filters = StockProduct(name: "Filters", level: .low)
        var task = HouseholdTask(title: "Change filter", intervalDays: 30, nextDueDate: .now)
        task.productId = filters.id
        try await store.addProduct(filters)
        try await store.addTask(task)
        let manager = manager()
        manager.beginUndoGrouping()
        try await store.deleteProduct(filters, undoManager: manager)
        manager.endUndoGrouping()
        #expect(manager.undoMenuItemTitle == "Undo Delete Product")
        manager.undo()
        try await F.waitUntil { store.householdTasks.first?.productId == filters.id }
        #expect(store.stockProducts.map(\.id) == [filters.id])
    }

    @Test("undoing an expense deletion restores it and moves the settlement back")
    func expenseUndo() async throws {
        let store = await F.makeStore()
        let expense = F.expense(2_000, by: F.guille)
        try await store.saveBudgetExpense(expense)
        let manager = manager()
        manager.beginUndoGrouping()
        try await store.deleteBudgetExpense(expense, undoManager: manager)
        manager.endUndoGrouping()
        #expect(store.budgetExpenses.isEmpty)
        manager.undo()
        try await F.waitUntil { store.budgetExpenses.count == 1 }
        #expect(store.budgetExpenses.first?.amountCents == 2_000)
    }
}
#endif
