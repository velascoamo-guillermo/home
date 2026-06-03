import Testing
import Foundation
@testable import Home

@Suite("ProductCategory") @MainActor struct ProductCategoryTests {
    @Test("raw values are stable lowercase strings")
    func rawValues() {
        #expect(ProductCategory.food.rawValue == "food")
        #expect(ProductCategory.cleaning.rawValue == "cleaning")
        #expect(ProductCategory.hygiene.rawValue == "hygiene")
        #expect(ProductCategory.other.rawValue == "other")
    }

    @Test("each case has a displayName and icon")
    func labelsAndIcons() {
        #expect(ProductCategory.food.displayName == "Food")
        #expect(ProductCategory.food.icon == "fork.knife")
        #expect(ProductCategory.allCases.count == 4)
    }
}
