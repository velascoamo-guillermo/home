import Foundation

extension SupabaseStore {
    /// Brings a soft-deleted task back with a fresh `updated_at`, so it wins last-write-wins
    /// against the tombstone that was already pushed.
    func restoreTask(_ task: HouseholdTask) async throws {
        var restored = task
        restored.deletedAt = nil
        restored.updatedAt = .now
        try await _local?.upsert([restored], enqueue: true)
        if let i = householdTasks.firstIndex(where: { $0.id == restored.id }) {
            householdTasks[i] = restored
        } else {
            householdTasks.append(restored)
        }
        await _sync?.sync(tables: [HouseholdTask.tableName])
    }

    /// `deleteProduct` unlinks tasks in memory only (their rows on disk keep `productId`),
    /// so a restore relinks the same tasks in memory. Only tasks still unlinked are touched,
    /// so a link the user changed between delete and restore isn't overwritten.
    func restoreProduct(_ product: StockProduct, relinking taskIDs: [UUID]) async throws {
        var restored = product
        restored.deletedAt = nil
        restored.updatedAt = .now
        try await _local?.upsert([restored], enqueue: true)
        if let i = stockProducts.firstIndex(where: { $0.id == restored.id }) {
            stockProducts[i] = restored
        } else {
            stockProducts.append(restored)
        }
        for i in householdTasks.indices
        where taskIDs.contains(householdTasks[i].id) && householdTasks[i].productId == nil {
            householdTasks[i].productId = restored.id
        }
        await _sync?.sync(tables: [StockProduct.tableName])
    }
}
