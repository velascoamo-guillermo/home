import Testing
import Foundation
@testable import Casita

@Suite("SupabaseStore – meals on stock levels") @MainActor struct MealStockLevelTests {

    private func entry(_ products: [StockProduct]) -> MealEntry {
        let meal = Meal(title: "Fried rice")
        return MealEntry(menuEntry: MenuEntry(dayOfWeek: 1, slot: .dinner, mealId: meal.id),
                         meal: meal, links: products.map { MealEntry.Link(product: $0) })
    }

    private func level(_ id: UUID, in store: SupabaseStore) -> StockLevel? {
        store.stockProducts.first { $0.id == id }?.level
    }

    @Test("cooking steps every linked product down one level and leaves Out at Out")
    func cookStepsDown() async throws {
        let store = SupabaseStore.makeTest()
        let rice = StockProduct(name: "Rice", level: .full)
        let eggs = StockProduct(name: "Eggs", level: .low)
        let salt = StockProduct(name: "Salt", level: .out)
        store.stockProducts = [rice, eggs, salt]

        try await store.cookMeal(entry([rice, eggs, salt]))

        #expect(level(rice.id, in: store) == .medium)
        #expect(level(eggs.id, in: store) == .out)
        #expect(level(salt.id, in: store) == .out)
    }

    @Test("cooking steps down from the current store level, not the entry snapshot")
    func cookUsesCurrentState() async throws {
        let store = SupabaseStore.makeTest()
        let current = StockProduct(name: "Rice", level: .medium)
        store.stockProducts = [current]

        try await store.cookMeal(entry([current.withLevel(.full)]))

        #expect(level(current.id, in: store) == .low)
    }

    @Test("setMealProducts stores one row per linked product with quantity 1")
    func setMealProductsQuantityOne() async throws {
        let store = SupabaseStore.makeTest()
        let meal = Meal(title: "Risotto")
        let rice = StockProduct(name: "Rice", level: .full)
        let peas = StockProduct(name: "Peas", level: .low)

        try await store.setMealProducts(for: meal, links: [MealEntry.Link(product: rice),
                                                           MealEntry.Link(product: peas)])

        #expect(Set(store.mealProducts.map(\.productId)) == [rice.id, peas.id])
        #expect(store.mealProducts.allSatisfy { $0.quantity == 1 && $0.mealId == meal.id })
    }
}
