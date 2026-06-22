import XCTest
@testable import Home

@MainActor
final class MealSuggestionTests: XCTestCase {
    private func decode(_ json: String) throws -> MealSuggestion {
        try JSONDecoder().decode(MealSuggestion.self, from: Data(json.utf8))
    }

    func testParsesTitleProductsAndNutrition() throws {
        let s = try decode("""
        {
          "title": "Arroz con pollo",
          "products": [{"name": "Rice", "quantity": 2}, {"name": "Chicken"}],
          "servings": 2,
          "calories": 600,
          "protein_g": 40,
          "carbs_g": 70,
          "fat_g": 15
        }
        """)
        XCTAssertEqual(s.title, "Arroz con pollo")
        XCTAssertEqual(s.products.count, 2)
        XCTAssertEqual(s.products[0].name, "Rice")
        XCTAssertEqual(s.products[0].quantity, 2)
        XCTAssertEqual(s.products[1].quantity, 1)
        XCTAssertEqual(s.servings, 2)
        XCTAssertEqual(s.nutrition.calories, 600)
    }

    func testParsesWithNullNutrition() throws {
        let s = try decode("""
        { "title": "Toast", "products": [], "servings": null,
          "calories": null, "protein_g": null, "carbs_g": null, "fat_g": null }
        """)
        XCTAssertEqual(s.title, "Toast")
        XCTAssertTrue(s.products.isEmpty)
        XCTAssertNil(s.servings)
        XCTAssertFalse(s.nutrition.hasAnyValue)
    }

    func testDropsNamelessProducts() throws {
        let s = try decode("""
        { "title": "X", "products": [{"name": ""}, {"quantity": 5}, {"name": "Rice"}] }
        """)
        XCTAssertEqual(s.products.map(\.name), ["Rice"])
    }

    func testThrowsOnInvalidJSON() {
        XCTAssertThrowsError(try decode("not json"))
    }

    func testResolveLinksMatchesProductsCaseInsensitively() {
        let rice = StockProduct(name: "Rice", icon: "leaf", packages: 1,
                                looseUnits: 0, unitsPerPackage: 10)
        let s = MealSuggestion(
            title: "X",
            products: [.init(name: "rice", quantity: 3), .init(name: "Unknown", quantity: 1)],
            servings: nil, nutrition: Nutrition())
        let links = s.resolveLinks(against: [rice])
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].product.id, rice.id)
        XCTAssertEqual(links[0].quantity, 3)
    }
}
