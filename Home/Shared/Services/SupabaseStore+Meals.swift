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
                return MealEntry.Link(product: product)
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
            MealProduct(mealId: meal.id, productId: $0.product.id)
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
        let matches = menuEntries.filter { $0.dayOfWeek == day && $0.slot == slot }
        if let keeper = matches.first {
            var updated = keeper
            updated.mealId = mealId
            updated.updatedAt = .now
            try await _local?.upsert([updated], enqueue: true)
            if let i = menuEntries.firstIndex(where: { $0.id == updated.id }) {
                menuEntries[i] = updated
            }
            let duplicates = matches.dropFirst()
            for dup in duplicates { try await _local?.softDelete(dup, enqueue: true) }
            if !duplicates.isEmpty {
                let duplicateIds = Set(duplicates.map(\.id))
                menuEntries.removeAll { duplicateIds.contains($0.id) }
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
        let matches = menuEntries.filter { $0.dayOfWeek == day && $0.slot == slot }
        guard !matches.isEmpty else { return }
        for entry in matches { try await _local?.softDelete(entry, enqueue: true) }
        let matchIds = Set(matches.map(\.id))
        menuEntries.removeAll { matchIds.contains($0.id) }
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

    func markMissingNeeded(for entry: MealEntry) async {
        for link in entry.shortLinks {
            guard var product = stockProducts.first(where: { $0.id == link.product.id }),
                  !product.needed else { continue }
            product.needed = true
            try? await updateProduct(product)
        }
    }

    func cookMeal(_ entry: MealEntry) async throws {
        for link in entry.links {
            let current = stockProducts.first(where: { $0.id == link.product.id }) ?? link.product
            guard current.level > .out else { continue }
            try await updateProduct(current.steppedDown())
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
        struct StockItem: Encodable { let name: String; let level: StockLevel }
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
            stock: stockProducts.map { StockItem(name: $0.name, level: $0.level) },
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
            guard Weekday(rawValue: choice.day) != nil,
                  mealEntry(day: choice.day, slot: choice.slot) == nil else { continue }
            guard let meal = Self.resolveChoice(choice, in: catalog) else { continue }
            try await assign(mealId: meal.id, day: choice.day, slot: choice.slot)
        }
    }

    /// Resolves a suggested `WeekMealChoice` to a catalog `Meal`, preferring an exact
    /// id match and falling back to a case-insensitive title match. Pulled out as a
    /// pure helper so the highest-risk part of `suggestWeek` is unit-testable without
    /// the surrounding network call.
    nonisolated static func resolveChoice(_ choice: WeekMealChoice, in catalog: [Meal]) -> Meal? {
        catalog.first { $0.id == choice.mealId }
            ?? catalog.first {
                guard let title = choice.title else { return false }
                return $0.title.compare(title, options: .caseInsensitive) == .orderedSame
            }
    }
}
