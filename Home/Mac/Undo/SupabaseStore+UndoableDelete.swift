#if os(macOS)
import Foundation

extension SupabaseStore {
    func deleteTask(_ task: HouseholdTask, undoManager: UndoManager?) async throws {
        try await deleteTask(task)
        DeletionUndo.register(
            on: undoManager, named: "Delete Task",
            undo: { [weak self] in await self?.run { try await $0.restoreTask(task) } ?? false },
            redo: { [weak self] in await self?.run { try await $0.deleteTask(task) } ?? false })
    }

    func deleteProduct(_ product: StockProduct, undoManager: UndoManager?,
                       named actionName: String = "Delete Product") async throws {
        let linked = householdTasks.filter { $0.productId == product.id }.map(\.id)
        try await deleteProduct(product)
        DeletionUndo.register(
            on: undoManager, named: actionName,
            undo: { [weak self] in
                await self?.run { try await $0.restoreProduct(product, relinking: linked) } ?? false
            },
            redo: { [weak self] in await self?.run { try await $0.deleteProduct(product) } ?? false })
    }

    func deleteBudgetExpense(_ expense: BudgetExpense, undoManager: UndoManager?) async throws {
        try await deleteBudgetExpense(expense)
        DeletionUndo.register(
            on: undoManager, named: "Delete Expense",
            undo: { [weak self] in await self?.run { try await $0.saveBudgetExpense(expense) } ?? false },
            redo: { [weak self] in await self?.run { try await $0.deleteBudgetExpense(expense) } ?? false })
    }

    /// Runs an undo/redo step, surfacing a failure as a dismissible `actionError` instead of
    /// swallowing it — a failed step must not look like it succeeded to the caller.
    private func run(_ action: (SupabaseStore) async throws -> Void) async -> Bool {
        do {
            try await action(self)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
}
#endif
