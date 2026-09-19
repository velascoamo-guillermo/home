import XCTest
@testable import Casita

@MainActor
final class MealEntryTests: XCTestCase {
    private func entry(_ levels: [StockLevel]) -> MealEntry {
        let meal = Meal(title: "X")
        return MealEntry(menuEntry: MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: meal.id),
                         meal: meal,
                         links: levels.map { MealEntry.Link(product: StockProduct(name: "Rice", level: $0)) })
    }

    func testShortWhenAnyLinkedProductIsOut() {
        XCTAssertTrue(entry([.full, .out]).isShort)
    }

    func testLowAndAboveAreNotShort() {
        XCTAssertFalse(entry([.low, .medium, .full]).isShort)
    }

    func testNotShortWhenNoLinks() {
        XCTAssertFalse(entry([]).isShort)
    }
}
