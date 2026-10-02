#if os(macOS)
import Foundation

extension SupabaseStore {
    func deleteTask(_ task: HouseholdTask, undoManager: UndoManager?) async throws {
        try await deleteTask(task)
        DeletionUndo.register(
            on: undoManager, named: "Delete Task",
            undo: { [weak self] in try? await self?.restoreTask(task) },
            redo: { [weak self] in try? await self?.deleteTask(task) })
    }

    func deleteProduct(_ product: StockProduct, undoManager: UndoManager?,
                       named actionName: String = "Delete Product") async throws {
        let linked = householdTasks.filter { $0.productId == product.id }.map(\.id)
        try await deleteProduct(product)
        DeletionUndo.register(
            on: undoManager, named: actionName,
            undo: { [weak self] in try? await self?.restoreProduct(product, relinking: linked) },
            redo: { [weak self] in try? await self?.deleteProduct(product) })
    }

    func deleteBudgetExpense(_ expense: BudgetExpense, undoManager: UndoManager?) async throws {
        try await deleteBudgetExpense(expense)
        DeletionUndo.register(
            on: undoManager, named: "Delete Expense",
            undo: { [weak self] in try? await self?.saveBudgetExpense(expense) },
            redo: { [weak self] in try? await self?.deleteBudgetExpense(expense) })
    }
}
#endif
