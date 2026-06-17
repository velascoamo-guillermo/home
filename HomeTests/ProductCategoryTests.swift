import Testing
import Foundation
@testable import Home

@Suite("ProductCategory") struct ProductCategoryTests {
    @Test("raw values are stable lowercase strings")
    func rawValues() {
        #expect(ProductCategory.food.rawValue == "food")
        #expect(ProductCategory.cleaning.rawValue == "cleaning")
        #expect(ProductCategory.hygiene.rawValue == "hygiene")
        #expect(ProductCategory.other.rawValue == "other")
    }

    @Test("each case has a non-empty displayName and icon")
    func labelsAndIcons() {
        for category in ProductCategory.allCases {
            #expect(!category.displayName.isEmpty)
            #expect(!category.icon.isEmpty)
        }
        #expect(ProductCategory.food.displayName == "Food")
        #expect(ProductCategory.food.icon == "fork.knife")
        #expect(ProductCategory.cleaning.displayName == "Cleaning")
        #expect(ProductCategory.hygiene.displayName == "Hygiene")
        #expect(ProductCategory.other.displayName == "Other")
    }

    @Test("Codable round-trip preserves raw value")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for category in ProductCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(ProductCategory.self, from: data)
            #expect(decoded == category)
        }
    }
}
