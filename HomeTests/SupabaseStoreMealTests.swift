import XCTest
@testable import Casita

@MainActor
final class SupabaseStoreMealTests: XCTestCase {
    func testMealEntryResolvesViaMenuEntry() {
        let store = SupabaseStore.makeTest()
        let rice = StockProduct(name: "Rice", icon: "leaf", packages: 1,
                                looseUnits: 0, unitsPerPackage: 10)
        let meal = Meal(title: "Risotto")
        store.stockProducts = [rice]
        store.meals = [meal]
        store.menuEntries = [MenuEntry(dayOfWeek: 2, slot: .dinner, mealId: meal.id)]
        store.mealProducts = [MealProduct(mealId: meal.id, productId: rice.id, quantity: 4)]

        let entry = store.mealEntry(day: 2, slot: .dinner)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.meal.title, "Risotto")
        XCTAssertEqual(entry?.links.count, 1)
        XCTAssertEqual(entry?.links.first?.quantity, 4)
    }

    func testMealEntryNilForEmptySlotAndDanglingMealId() {
        let store = SupabaseStore.makeTest()
        XCTAssertNil(store.mealEntry(day: 5, slot: .lunch))
        store.menuEntries = [MenuEntry(dayOfWeek: 5, slot: .lunch, mealId: UUID())]
        XCTAssertNil(store.mealEntry(day: 5, slot: .lunch))
    }

    func testAssignInsertsThenRepoints() async throws {
        let store = SupabaseStore.makeTest()
        let pasta = Meal(title: "Pasta")
        let salad = Meal(title: "Salad")
        store.meals = [pasta, salad]

        try await store.assign(mealId: pasta.id, day: 1, slot: .lunch)
        XCTAssertEqual(store.menuEntries.count, 1)
        XCTAssertEqual(store.mealEntry(day: 1, slot: .lunch)?.meal.title, "Pasta")

        try await store.assign(mealId: salad.id, day: 1, slot: .lunch)
        XCTAssertEqual(store.menuEntries.count, 1)
        XCTAssertEqual(store.mealEntry(day: 1, slot: .lunch)?.meal.title, "Salad")
    }

    func testUnassignRemovesEntryKeepsMeal() async throws {
        let store = SupabaseStore.makeTest()
        let meal = Meal(title: "Pasta")
        store.meals = [meal]
        try await store.assign(mealId: meal.id, day: 3, slot: .dinner)
        try await store.unassign(day: 3, slot: .dinner)
        XCTAssertTrue(store.menuEntries.isEmpty)
        XCTAssertEqual(store.meals.count, 1)
    }

    func testClearDayUnassignsOnlyThatDay() async throws {
        let store = SupabaseStore.makeTest()
        let meal = Meal(title: "Pasta")
        store.meals = [meal]
        try await store.assign(mealId: meal.id, day: 2, slot: .lunch)
        try await store.assign(mealId: meal.id, day: 2, slot: .dinner)
        try await store.assign(mealId: meal.id, day: 4, slot: .lunch)
        try await store.clearDay(2)
        XCTAssertEqual(store.menuEntries.map(\.dayOfWeek), [4])
        XCTAssertEqual(store.meals.count, 1)
    }

    func testDeleteMealCascadesEntriesAndProducts() async throws {
        let store = SupabaseStore.makeTest()
        let meal = Meal(title: "Pasta")
        store.meals = [meal]
        store.mealProducts = [MealProduct(mealId: meal.id, productId: UUID(), quantity: 1)]
        try await store.assign(mealId: meal.id, day: 6, slot: .dinner)
        try await store.deleteMeal(meal)
        XCTAssertTrue(store.meals.isEmpty)
        XCTAssertTrue(store.menuEntries.isEmpty)
        XCTAssertTrue(store.mealProducts.isEmpty)
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
