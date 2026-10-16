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
                              undo: { probe.calls.append("restore"); return true },
                              redo: { probe.calls.append("delete"); return true })
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

    @Test("a failed undo does not register redo")
    func failedUndoDoesNotRegisterRedo() async throws {
        let manager = manager()
        let probe = UndoProbe()
        manager.beginUndoGrouping()
        DeletionUndo.register(on: manager, named: "Delete Task",
                              undo: { probe.calls.append("restore"); return false },
                              redo: { probe.calls.append("delete"); return true })
        manager.endUndoGrouping()

        manager.undo()
        try await F.waitUntil { probe.calls == ["restore"] }
        #expect(probe.calls == ["restore"])
        #expect(!manager.canRedo)
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
        #expect(store.householdTasks.first?.productId == filters.id)
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

    @Test("undoing a meal deletion restores links and slots, redo deletes again")
    func mealUndoRedo() async throws {
        let store = await F.makeStore()
        let meal = Meal(title: "Lentils")
        let product = StockProduct(name: "Lentils", level: .full)
        try await store.addProduct(product)
        try await store.addMeal(meal)
        try await store.setMealProducts(for: meal, links: [MealEntry.Link(product: product)])
        try await store.assign(mealId: meal.id, day: 3, slot: .dinner)
        let manager = manager()
        manager.beginUndoGrouping()
        try await store.deleteMeal(meal, undoManager: manager)
        manager.endUndoGrouping()
        #expect(manager.undoMenuItemTitle == "Undo Delete Meal")
        #expect(store.meals.isEmpty && store.mealProducts.isEmpty && store.menuEntries.isEmpty)
        manager.undo()
        try await F.waitUntil { store.meals.count == 1 }
        #expect(store.mealProducts.count == 1)
        #expect(store.mealProducts.first?.productId == product.id)
        #expect(store.menuEntries.count == 1)
        #expect(store.menuEntries.first?.dayOfWeek == 3)
        #expect(store.menuEntries.first?.slot == .dinner)
        manager.redo()
        try await F.waitUntil { store.meals.isEmpty }
        #expect(store.mealProducts.isEmpty && store.menuEntries.isEmpty)
        manager.undo()
        try await F.waitUntil { store.meals.count == 1 }
        #expect(store.mealProducts.count == 1 && store.menuEntries.count == 1)
    }

    @Test("redo re-snapshots the meal, so edits made after an undo survive the next undo")
    func mealRedoResnapshots() async throws {
        let url = F.tempURL()
        let store = await F.makeStore(url: url)
        let meal = Meal(title: "Lentils")
        let oldProduct = StockProduct(name: "Lentils", level: .full)
        let newProduct = StockProduct(name: "Rice", level: .full)
        try await store.addProduct(oldProduct)
        try await store.addProduct(newProduct)
        try await store.addMeal(meal)
        try await store.setMealProducts(for: meal, links: [MealEntry.Link(product: oldProduct)])
        let manager = manager()
        manager.beginUndoGrouping()
        try await store.deleteMeal(meal, undoManager: manager)
        manager.endUndoGrouping()
        manager.undo()
        try await F.waitUntil { store.meals.count == 1 }

        var edited = try #require(store.meals.first)
        edited.title = "Rice and lentils"
        try await store.updateMeal(edited)
        try await store.setMealProducts(for: edited, links: [MealEntry.Link(product: newProduct)])

        manager.redo()
        try await F.waitUntil { store.meals.isEmpty }
        manager.undo()
        try await F.waitUntil { store.meals.count == 1 }
        #expect(store.meals.first?.title == "Rice and lentils")
        #expect(store.mealProducts.map(\.productId) == [newProduct.id])
        let reloaded = await F.makeStore(url: url)
        #expect(reloaded.meals.first?.title == "Rice and lentils")
        #expect(reloaded.mealProducts.map(\.productId) == [newProduct.id])
    }
}
#endif
