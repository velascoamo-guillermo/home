import Foundation
import Supabase

extension SupabaseStore {

    func mealEntry(day: Int, slot: MealSlot) -> MealEntry? {
        guard let meal = meals.first(where: { $0.dayOfWeek == day && $0.slot == slot }) else {
            return nil
        }
        let links: [MealEntry.Link] = mealProducts
            .filter { $0.mealId == meal.id }
            .compactMap { mp in
                guard let product = stockProducts.first(where: { $0.id == mp.productId }) else {
                    return nil
                }
                return MealEntry.Link(product: product, quantity: mp.quantity)
            }
        return MealEntry(meal: meal, links: links)
    }

    func addMeal(_ meal: Meal) async throws {
        var m = meal; m.updatedAt = .now
        try await _local?.upsert([m], enqueue: true)
        meals.append(m)
        await _sync?.sync(tables: [Meal.tableName])
    }

    func updateMeal(_ meal: Meal) async throws {
        var m = meal; m.updatedAt = .now
        try await _local?.upsert([m], enqueue: true)
        if let i = meals.firstIndex(where: { $0.id == m.id }) { meals[i] = m }
        await _sync?.sync(tables: [Meal.tableName])
    }

    func deleteMeal(_ meal: Meal) async throws {
        try await _local?.softDelete(meal, enqueue: true)
        meals.removeAll { $0.id == meal.id }
        // MealProducts are child rows — soft-delete them too so they sync
        let childProducts = mealProducts.filter { $0.mealId == meal.id }
        for mp in childProducts { try await _local?.softDelete(mp, enqueue: true) }
        mealProducts.removeAll { $0.mealId == meal.id }
        await _sync?.sync(tables: [Meal.tableName, MealProduct.tableName])
    }

    /// Deletes every meal (and its product links) for a weekday.
    func clearDay(_ day: Int) async throws {
        let toDelete = meals.filter { $0.dayOfWeek == day }
        guard !toDelete.isEmpty else { return }
        let ids = toDelete.map(\.id)
        for m in toDelete { try await _local?.softDelete(m, enqueue: true) }
        let childProducts = mealProducts.filter { ids.contains($0.mealId) }
        for mp in childProducts { try await _local?.softDelete(mp, enqueue: true) }
        meals.removeAll { ids.contains($0.id) }
        mealProducts.removeAll { ids.contains($0.mealId) }
        await _sync?.sync(tables: [Meal.tableName, MealProduct.tableName])
    }

    func setMealProducts(for meal: Meal, links: [MealEntry.Link]) async throws {
        // Soft-delete existing products for this meal
        let existing = mealProducts.filter { $0.mealId == meal.id }
        for mp in existing { try await _local?.softDelete(mp, enqueue: true) }
        mealProducts.removeAll { $0.mealId == meal.id }
        // Insert the new ones
        let rows = links.map {
            MealProduct(mealId: meal.id, productId: $0.product.id, quantity: $0.quantity)
        }
        if !rows.isEmpty {
            let stamped = rows.map { mp -> MealProduct in var m = mp; m.updatedAt = .now; return m }
            try await _local?.upsert(stamped, enqueue: true)
            mealProducts.append(contentsOf: stamped)
        }
        await _sync?.sync(tables: [MealProduct.tableName])
    }

    func cookMeal(_ entry: MealEntry) async throws {
        for link in entry.links {
            let current = stockProducts.first(where: { $0.id == link.product.id }) ?? link.product
            let take = min(link.quantity, current.totalUnits)
            guard take > 0, let consumed = current.consuming(units: take) else { continue }
            try await updateProduct(consumed)
        }
    }

    /// Empty (day, slot) combinations across the whole week.
    var emptyMealSlots: [(day: Int, slot: MealSlot)] {
        Weekday.allCases.flatMap { weekday in
            MealSlot.allCases.compactMap { slot in
                mealEntry(day: weekday.rawValue, slot: slot) == nil
                    ? (day: weekday.rawValue, slot: slot)
                    : nil
            }
        }
    }

    /// Asks the model to plan every empty slot of the week in a single call,
    /// then auto-saves the suggestions as meals with their product links.
    func suggestWeek() async throws {
        guard reachability.isOnline else { throw SyncError.requiresConnection }
        struct StockItem: Encodable { let name: String; let totalUnits: Int }
        struct SlotRef: Encodable { let day: Int; let slot: String }
        struct PlannedRef: Encodable { let day: Int; let slot: String; let title: String }
        struct RequestBody: Encodable {
            let stock: [StockItem]
            let slots: [SlotRef]
            let planned: [PlannedRef]
        }

        let slots = emptyMealSlots
        guard !slots.isEmpty else { return }

        let planned: [PlannedRef] = meals
            .filter { !$0.title.isEmpty }
            .map { PlannedRef(day: $0.dayOfWeek, slot: $0.slot.rawValue, title: $0.title) }

        let body = RequestBody(
            stock: stockProducts.map { StockItem(name: $0.name, totalUnits: $0.totalUnits) },
            slots: slots.map { SlotRef(day: $0.day, slot: $0.slot.rawValue) },
            planned: planned
        )

        let suggestions: [WeekMealSuggestion]
        do {
            suggestions = try await client.functions
                .invoke("suggest-meal", options: FunctionInvokeOptions(body: body))
        } catch let fnError as FunctionsError {
            switch fnError {
            case .httpError(let code, _): throw SuggestionError.invalidResponse(code)
            case .relayError:             throw SuggestionError.networkError(fnError)
            }
        } catch let e as SuggestionError {
            throw e
        } catch {
            throw SuggestionError.networkError(error)
        }

        for suggestion in suggestions {
            // Skip slots that are no longer empty (model may echo extras).
            guard mealEntry(day: suggestion.day, slot: suggestion.slot) == nil else { continue }
            let meal = Meal(
                dayOfWeek: suggestion.day,
                slot: suggestion.slot,
                title: suggestion.title,
                servings: suggestion.servings,
                nutrition: suggestion.nutrition
            )
            try await addMeal(meal)
            let links = suggestion.resolveLinks(against: stockProducts)
            if !links.isEmpty {
                try await setMealProducts(for: meal, links: links)
            }
        }
    }
}
