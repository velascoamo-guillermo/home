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

    /// Reverses `deleteMeal`'s cascade. A week slot taken by another meal since the delete stays
    /// with that newer choice, and a link whose product is gone is dropped rather than dangling.
    func restoreMeal(_ meal: Meal, products: [MealProduct], entries: [MenuEntry]) async throws {
        var restoredMeal = meal
        restoredMeal.deletedAt = nil
        restoredMeal.updatedAt = .now
        try await _local?.upsert([restoredMeal], enqueue: true)
        if let i = meals.firstIndex(where: { $0.id == restoredMeal.id }) {
            meals[i] = restoredMeal
        } else {
            meals.append(restoredMeal)
        }

        let liveProductIDs = Set(stockProducts.map(\.id))
        let links: [MealProduct] = products
            .filter { liveProductIDs.contains($0.productId) }
            .map { var l = $0; l.deletedAt = nil; l.updatedAt = .now; return l }
        if !links.isEmpty {
            try await _local?.upsert(links, enqueue: true)
            for link in links {
                if let i = mealProducts.firstIndex(where: { $0.id == link.id }) {
                    mealProducts[i] = link
                } else {
                    mealProducts.append(link)
                }
            }
        }

        var restoredEntries: [MenuEntry] = []
        for var entry in entries {
            let taken = menuEntries.contains {
                $0.id != entry.id && $0.dayOfWeek == entry.dayOfWeek && $0.slot == entry.slot
            }
            if taken { continue }
            entry.deletedAt = nil
            entry.updatedAt = .now
            restoredEntries.append(entry)
        }
        if !restoredEntries.isEmpty {
            try await _local?.upsert(restoredEntries, enqueue: true)
            for entry in restoredEntries {
                if let i = menuEntries.firstIndex(where: { $0.id == entry.id }) {
                    menuEntries[i] = entry
                } else {
                    menuEntries.append(entry)
                }
            }
        }
        await _sync?.sync(tables: [Meal.tableName, MealProduct.tableName, MenuEntry.tableName])
    }
}
