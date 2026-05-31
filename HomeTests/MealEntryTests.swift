import XCTest
@testable import Home

final class MealEntryTests: XCTestCase {
    private func product(units: Int) -> StockProduct {
        StockProduct(name: "Rice", icon: "leaf", packages: 0,
                     looseUnits: units, unitsPerPackage: 1)
    }

    func testShortWhenQuantityExceedsStock() {
        let p = product(units: 1)
        let meal = Meal(dayOfWeek: 1, slot: .lunch, title: "X")
        let entry = MealEntry(meal: meal, links: [MealEntry.Link(product: p, quantity: 2)])
        XCTAssertTrue(entry.isShort)
    }

    func testNotShortWhenStockSufficient() {
        let p = product(units: 5)
        let meal = Meal(dayOfWeek: 1, slot: .lunch, title: "X")
        let entry = MealEntry(meal: meal, links: [MealEntry.Link(product: p, quantity: 5)])
        XCTAssertFalse(entry.isShort)
    }

    func testNotShortWhenNoLinks() {
        let meal = Meal(dayOfWeek: 1, slot: .lunch, title: "X")
        let entry = MealEntry(meal: meal, links: [])
        XCTAssertFalse(entry.isShort)
    }
}
