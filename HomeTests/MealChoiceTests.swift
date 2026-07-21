import XCTest
@testable import Casita

@MainActor
final class MealChoiceTests: XCTestCase {
    private func decode(_ json: String) throws -> WeekMealChoice {
        try JSONDecoder().decode(WeekMealChoice.self, from: Data(json.utf8))
    }

    func testParsesDaySlotAndMealId() throws {
        let c = try decode("""
        {
          "day": 3,
          "slot": "dinner",
          "meal_id": "00000000-0000-0000-0000-000000000001",
          "title": "Arroz con pollo"
        }
        """)
        XCTAssertEqual(c.day, 3)
        XCTAssertEqual(c.slot, .dinner)
        XCTAssertEqual(c.mealId, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(c.title, "Arroz con pollo")
    }

    func testParsesWithoutMealId() throws {
        let c = try decode("""
        { "day": 1, "slot": "lunch", "title": "Tostadas" }
        """)
        XCTAssertNil(c.mealId)
        XCTAssertEqual(c.title, "Tostadas")
    }

    func testParsesMalformedMealIdAsNil() throws {
        let c = try decode("""
        { "day": 1, "slot": "lunch", "meal_id": "not-a-uuid", "title": "X" }
        """)
        XCTAssertNil(c.mealId)
    }
}
