import XCTest
@testable import Casita

@MainActor
final class SupabaseStoreMealTests: XCTestCase {
    func testMealEntryResolvesViaMenuEntry() {
        let store = SupabaseStore.makeTest()
        let rice = StockProduct(name: "Rice", packages: 1,
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

    func testMealEntrySkipsLinksWithMissingProduct() {
        let store = SupabaseStore.makeTest()
        let meal = Meal(title: "X")
        store.meals = [meal]
        store.menuEntries = [MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: meal.id)]
        store.mealProducts = [MealProduct(mealId: meal.id, productId: UUID(), quantity: 1)]
        let entry = store.mealEntry(day: 1, slot: .lunch)
        XCTAssertEqual(entry?.links.count, 0)
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

    func testAssignLeavesExactlyOneEntryWhenDuplicatesExist() async throws {
        let store = SupabaseStore.makeTest()
        let pasta = Meal(title: "Pasta")
        let salad = Meal(title: "Salad")
        let curry = Meal(title: "Curry")
        store.meals = [pasta, salad, curry]
        // Simulates two offline devices each creating their own MenuEntry
        // for the same (day, slot) before sync reconciles them.
        store.menuEntries = [
            MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: pasta.id),
            MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: salad.id)
        ]

        try await store.assign(mealId: curry.id, day: 1, slot: .lunch)

        let matching = store.menuEntries.filter { $0.dayOfWeek == 1 && $0.slot == .lunch }
        XCTAssertEqual(matching.count, 1)
        XCTAssertEqual(matching.first?.mealId, curry.id)
    }

    func testUnassignClearsSlotWithDuplicateEntries() async throws {
        let store = SupabaseStore.makeTest()
        let pasta = Meal(title: "Pasta")
        let salad = Meal(title: "Salad")
        store.meals = [pasta, salad]
        store.menuEntries = [
            MenuEntry(dayOfWeek: 4, slot: .dinner, mealId: pasta.id),
            MenuEntry(dayOfWeek: 4, slot: .dinner, mealId: salad.id)
        ]

        try await store.unassign(day: 4, slot: .dinner)

        XCTAssertNil(store.mealEntry(day: 4, slot: .dinner))
        XCTAssertTrue(store.menuEntries.filter { $0.dayOfWeek == 4 && $0.slot == .dinner }.isEmpty)
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

    private func decodeChoice(day: Int = 1, slot: MealSlot = .lunch,
                               mealId: UUID? = nil, title: String? = nil) throws -> WeekMealChoice {
        var json = "{ \"day\": \(day), \"slot\": \"\(slot.rawValue)\""
        if let mealId { json += ", \"meal_id\": \"\(mealId.uuidString)\"" }
        if let title { json += ", \"title\": \"\(title)\"" }
        json += " }"
        return try JSONDecoder().decode(WeekMealChoice.self, from: Data(json.utf8))
    }

    func testResolveChoicePrefersMealIdOverTitle() throws {
        let pasta = Meal(title: "Pasta")
        let salad = Meal(title: "Salad")
        let choice = try decodeChoice(mealId: salad.id, title: "Pasta")
        let resolved = SupabaseStore.resolveChoice(choice, in: [pasta, salad])
        XCTAssertEqual(resolved?.id, salad.id)
    }

    func testResolveChoiceFallsBackToCaseInsensitiveTitleMatch() throws {
        let curry = Meal(title: "Chicken Curry")
        let choice = try decodeChoice(title: "chicken CURRY")
        let resolved = SupabaseStore.resolveChoice(choice, in: [curry])
        XCTAssertEqual(resolved?.id, curry.id)
    }

    func testResolveChoiceReturnsNilWhenNoIdOrTitleMatches() throws {
        let curry = Meal(title: "Chicken Curry")
        let choice = try decodeChoice(mealId: UUID(), title: "Beef Stew")
        XCTAssertNil(SupabaseStore.resolveChoice(choice, in: [curry]))
    }

    /// `suggestWeek` performs a live network call via `client.functions.invoke`, so its
    /// full day-range guard (`Weekday(rawValue: choice.day) != nil`) cannot be exercised
    /// end-to-end without a mocking framework, which is out of scope here. This test
    /// instead verifies the exact predicate that guard relies on: `Weekday`'s raw values
    /// are 1...7, so day 0 and day 8 (the values an unvalidated LLM response could send)
    /// are rejected while the full valid range is accepted.
    func testWeekdayRawValueRangeMatchesSuggestWeekGuard() {
        XCTAssertNil(Weekday(rawValue: 0))
        XCTAssertNil(Weekday(rawValue: 8))
        for day in 1...7 {
            XCTAssertNotNil(Weekday(rawValue: day))
        }
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
        let p = StockProduct(name: "Eggs", packages: 0,
                             looseUnits: 2, unitsPerPackage: 1)
        XCTAssertNil(p.consuming(units: 3))
        let take = min(3, p.totalUnits)
        XCTAssertEqual(take, 2)
        XCTAssertEqual(p.consuming(units: take)?.totalUnits, 0)
    }
}
