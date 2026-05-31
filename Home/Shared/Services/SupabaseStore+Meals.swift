import Foundation

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
        try await client.from("meals").insert(meal).execute()
        meals.append(meal)
    }

    func updateMeal(_ meal: Meal) async throws {
        try await client.from("meals").update(meal).eq("id", value: meal.id).execute()
        if let i = meals.firstIndex(where: { $0.id == meal.id }) {
            meals[i] = meal
        }
    }

    func deleteMeal(_ meal: Meal) async throws {
        try await client.from("meals").delete().eq("id", value: meal.id).execute()
        meals.removeAll { $0.id == meal.id }
        mealProducts.removeAll { $0.mealId == meal.id }
    }

    func setMealProducts(for meal: Meal, links: [MealEntry.Link]) async throws {
        try await client.from("meal_products").delete().eq("meal_id", value: meal.id).execute()
        mealProducts.removeAll { $0.mealId == meal.id }
        let rows = links.map {
            MealProduct(mealId: meal.id, productId: $0.product.id, quantity: $0.quantity)
        }
        if !rows.isEmpty {
            try await client.from("meal_products").insert(rows).execute()
            mealProducts.append(contentsOf: rows)
        }
    }

    func cookMeal(_ entry: MealEntry) async throws {
        for link in entry.links {
            let current = stockProducts.first(where: { $0.id == link.product.id }) ?? link.product
            let take = min(link.quantity, current.totalUnits)
            guard take > 0, let consumed = current.consuming(units: take) else { continue }
            try await updateProduct(consumed)
        }
    }
}
