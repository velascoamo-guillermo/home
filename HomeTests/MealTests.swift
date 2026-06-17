import XCTest
@testable import Home

@MainActor
final class MealTests: XCTestCase {
    func testMealDecodesFromSupabaseSnakeCase() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "day_of_week": 3,
          "slot": "dinner",
          "title": "Pasta",
          "servings": 2,
          "calories": 520,
          "protein_g": 25,
          "carbs_g": 60,
          "fat_g": 18,
          "created_at": "2026-05-31T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meal = try decoder.decode(Meal.self, from: json)

        XCTAssertEqual(meal.dayOfWeek, 3)
        XCTAssertEqual(meal.slot, .dinner)
        XCTAssertEqual(meal.title, "Pasta")
        XCTAssertEqual(meal.nutrition.calories, 520)
        XCTAssertEqual(meal.nutrition.proteinG, 25)
        XCTAssertEqual(meal.servings, 2)
    }

    func testMealDecodesWithNullNutrition() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "day_of_week": 1,
          "slot": "lunch",
          "title": "",
          "servings": null,
          "calories": null,
          "protein_g": null,
          "carbs_g": null,
          "fat_g": null,
          "created_at": "2026-05-31T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meal = try decoder.decode(Meal.self, from: json)

        XCTAssertEqual(meal.slot, .lunch)
        XCTAssertNil(meal.servings)
        XCTAssertNil(meal.nutrition.calories)
        XCTAssertFalse(meal.nutrition.hasAnyValue)
    }
}

extension MealTests {
    func testWeekdayOrderingAndNames() {
        XCTAssertEqual(Weekday.allCases.map(\.rawValue), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(Weekday(rawValue: 1)?.displayName, "Lunes")
        XCTAssertEqual(Weekday(rawValue: 7)?.displayName, "Domingo")
    }
}

extension MealTests {
    func testMealProductDecodesSnakeCase() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-0000000000aa",
          "meal_id": "00000000-0000-0000-0000-000000000001",
          "product_id": "00000000-0000-0000-0000-0000000000bb",
          "quantity": 3,
          "updated_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let mp = try JSONDecoder().decode(MealProduct.self, from: json)
        XCTAssertEqual(mp.quantity, 3)
        XCTAssertEqual(mp.mealId.uuidString.lowercased(), "00000000-0000-0000-0000-000000000001")
    }
}
