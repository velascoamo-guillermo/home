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
    ///
    /// HIG decision (minimal, documented rather than a full retry affordance): a failed Undo
    /// or Redo already has no system-standard retry UI on macOS — `UndoManager` offers no way
    /// to re-arm a stack entry that already ran. Re-registering the same step for a one-tap
    /// retry would risk a stale, silently-stacking Undo/Redo entry if the underlying failure is
    /// persistent (e.g. offline). Instead: (1) the alert's message names the failure so the
    /// person can act (retry their connection, etc.), and (2) `DeletionUndo.Step.run` removes
    /// the speculative inverse registration on failure so the opposite stack never offers a
    /// stale "Undo"/"Redo" for a change that never actually happened — see
    /// `DeletionUndoTests.failedUndoDoesNotRegisterRedo`. The person can re-trigger the same
    /// delete/restore from the feature UI itself, which re-enters this same undo-aware path.
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
