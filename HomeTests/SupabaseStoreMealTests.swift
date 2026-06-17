import XCTest
@testable import Home

@MainActor
final class SupabaseStoreMealTests: XCTestCase {
    func testMealEntryResolvesLinkedProducts() {
        let store = SupabaseStore()
        let rice = StockProduct(name: "Rice", icon: "leaf", packages: 1,
                                looseUnits: 0, unitsPerPackage: 10)
        let meal = Meal(dayOfWeek: 2, slot: .dinner, title: "Risotto")
        store.stockProducts = [rice]
        store.meals = [meal]
        store.mealProducts = [MealProduct(mealId: meal.id, productId: rice.id, quantity: 4)]

        let entry = store.mealEntry(day: 2, slot: .dinner)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.meal.title, "Risotto")
        XCTAssertEqual(entry?.links.count, 1)
        XCTAssertEqual(entry?.links.first?.quantity, 4)
        XCTAssertEqual(entry?.links.first?.product.id, rice.id)
    }

    func testMealEntryNilForEmptySlot() {
        let store = SupabaseStore()
        XCTAssertNil(store.mealEntry(day: 5, slot: .lunch))
    }

    func testMealEntrySkipsLinksWithMissingProduct() {
        let store = SupabaseStore()
        let meal = Meal(dayOfWeek: 1, slot: .lunch, title: "X")
        store.meals = [meal]
        store.mealProducts = [MealProduct(mealId: meal.id, productId: UUID(), quantity: 1)]
        let entry = store.mealEntry(day: 1, slot: .lunch)
        XCTAssertEqual(entry?.links.count, 0)
    }
}

extension SupabaseStoreMealTests {
    func testConsumingClampsAtAvailableUnits() {
        let p = StockProduct(name: "Eggs", icon: "leaf", packages: 0,
                             looseUnits: 2, unitsPerPackage: 1)
        XCTAssertNil(p.consuming(units: 3))
        let take = min(3, p.totalUnits)
        XCTAssertEqual(take, 2)
        XCTAssertEqual(p.consuming(units: take)?.totalUnits, 0)
    }
}
