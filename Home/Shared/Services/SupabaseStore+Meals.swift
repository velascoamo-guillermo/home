import Foundation
import Supabase

extension SupabaseStore {

    func mealEntry(day: Int, slot: MealSlot) -> MealEntry? {
        guard let entry = menuEntries.first(where: { $0.dayOfWeek == day && $0.slot == slot }),
              let meal = meals.first(where: { $0.id == entry.mealId }) else {
            return nil
        }
        return MealEntry(menuEntry: entry, meal: meal, links: links(for: meal.id))
    }

    private func links(for mealId: UUID) -> [MealEntry.Link] {
        mealProducts
            .filter { $0.mealId == mealId }
            .compactMap { mp in
                guard let product = stockProducts.first(where: { $0.id == mp.productId }) else {
                    return nil
                }
                return MealEntry.Link(product: product, quantity: mp.quantity)
            }
    }

    // MARK: - Catalog

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
        let childProducts = mealProducts.filter { $0.mealId == meal.id }
        for mp in childProducts { try await _local?.softDelete(mp, enqueue: true) }
        mealProducts.removeAll { $0.mealId == meal.id }
        let entries = menuEntries.filter { $0.mealId == meal.id }
        for e in entries { try await _local?.softDelete(e, enqueue: true) }
        menuEntries.removeAll { $0.mealId == meal.id }
        await _sync?.sync(tables: [Meal.tableName, MealProduct.tableName, MenuEntry.tableName])
    }

    func setMealProducts(for meal: Meal, links: [MealEntry.Link]) async throws {
        let existing = mealProducts.filter { $0.mealId == meal.id }
        for mp in existing { try await _local?.softDelete(mp, enqueue: true) }
        mealProducts.removeAll { $0.mealId == meal.id }
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

    // MARK: - Weekly menu

    func assign(mealId: UUID, day: Int, slot: MealSlot) async throws {
        if var existing = menuEntries.first(where: { $0.dayOfWeek == day && $0.slot == slot }) {
            existing.mealId = mealId
            existing.updatedAt = .now
            try await _local?.upsert([existing], enqueue: true)
            if let i = menuEntries.firstIndex(where: { $0.id == existing.id }) {
                menuEntries[i] = existing
            }
        } else {
            var entry = MenuEntry(dayOfWeek: day, slot: slot, mealId: mealId)
            entry.updatedAt = .now
            try await _local?.upsert([entry], enqueue: true)
            menuEntries.append(entry)
        }
        await _sync?.sync(tables: [MenuEntry.tableName])
    }

    func unassign(day: Int, slot: MealSlot) async throws {
        guard let entry = menuEntries.first(where: { $0.dayOfWeek == day && $0.slot == slot })
        else { return }
        try await _local?.softDelete(entry, enqueue: true)
        menuEntries.removeAll { $0.id == entry.id }
        await _sync?.sync(tables: [MenuEntry.tableName])
    }

    /// Unassigns every slot of a weekday. Catalog meals are untouched.
    func clearDay(_ day: Int) async throws {
        let toRemove = menuEntries.filter { $0.dayOfWeek == day }
        guard !toRemove.isEmpty else { return }
        for e in toRemove { try await _local?.softDelete(e, enqueue: true) }
        menuEntries.removeAll { $0.dayOfWeek == day }
        await _sync?.sync(tables: [MenuEntry.tableName])
    }

    func cookMeal(_ entry: MealEntry) async throws {
        for link in entry.links {
            let current = stockProducts.first(where: { $0.id == link.product.id }) ?? link.product
            let take = min(link.quantity, current.totalUnits)
            guard take > 0, let consumed = current.consuming(units: take) else { continue }
            try await updateProduct(consumed)
        }
    }

    var emptyMealSlots: [(day: Int, slot: MealSlot)] {
        Weekday.allCases.flatMap { weekday in
            MealSlot.allCases.compactMap { slot in
                mealEntry(day: weekday.rawValue, slot: slot) == nil
                    ? (day: weekday.rawValue, slot: slot)
                    : nil
            }
        }
    }

    /// Asks the model to fill every empty slot by choosing from the catalog.
    func suggestWeek() async throws {
        guard reachability.isOnline else { throw SyncError.requiresConnection }
        struct CatalogItem: Encodable { let id: UUID; let title: String }
        struct StockItem: Encodable { let name: String; let totalUnits: Int }
        struct SlotRef: Encodable { let day: Int; let slot: String }
        struct PlannedRef: Encodable { let day: Int; let slot: String; let title: String }
        struct RequestBody: Encodable {
            let catalog: [CatalogItem]
            let stock: [StockItem]
            let slots: [SlotRef]
            let planned: [PlannedRef]
        }

        let slots = emptyMealSlots
        guard !slots.isEmpty else { return }
        let catalog = meals.filter { !$0.title.isEmpty }
        guard !catalog.isEmpty else { return }

        let planned: [PlannedRef] = menuEntries.compactMap { entry in
            guard let meal = meals.first(where: { $0.id == entry.mealId }),
                  !meal.title.isEmpty else { return nil }
            return PlannedRef(day: entry.dayOfWeek, slot: entry.slot.rawValue, title: meal.title)
        }

        let body = RequestBody(
            catalog: catalog.map { CatalogItem(id: $0.id, title: $0.title) },
            stock: stockProducts.map { StockItem(name: $0.name, totalUnits: $0.totalUnits) },
            slots: slots.map { SlotRef(day: $0.day, slot: $0.slot.rawValue) },
            planned: planned
        )

        let choices: [WeekMealChoice]
        do {
            choices = try await client.functions
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

        for choice in choices {
            guard mealEntry(day: choice.day, slot: choice.slot) == nil else { continue }
            let meal = catalog.first { $0.id == choice.mealId }
                ?? catalog.first {
                    guard let title = choice.title else { return false }
                    return $0.title.compare(title, options: .caseInsensitive) == .orderedSame
                }
            guard let meal else { continue }
            try await assign(mealId: meal.id, day: choice.day, slot: choice.slot)
        }
    }
}
