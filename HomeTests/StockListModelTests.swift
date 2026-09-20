import Testing
import Foundation
@testable import Casita

@Suite("StockListModel") @MainActor struct StockListModelTests {

    private func product(_ name: String, _ level: StockLevel, _ category: ProductCategory? = nil) -> StockProduct {
        StockProduct(name: name, level: level, category: category)
    }

    private var sample: [StockProduct] {
        [
            product("Milk", .full, .food),
            product("Bleach", .out, .cleaning),
            product("Eggs", .low, .food),
            product("Apples", .low, .food),
            product("Café", .medium, .food),
            product("Batteries", .medium),
            product("Soap", .out, .hygiene),
        ]
    }

    private func names(_ model: StockListModel) -> [String] {
        model.groups.flatMap(\.products).map(\.name)
    }

    @Test("chip counts and titles cover every product regardless of search")
    func counts() {
        let model = StockListModel(products: sample, query: "milk")
        #expect(model.count(for: .all) == 7)
        #expect(model.count(for: .out) == 2)
        #expect(model.count(for: .low) == 2)
        #expect(model.title(for: .all) == "All 7")
        #expect(model.title(for: .out) == "Out 2")
        #expect(model.title(for: .low) == "Low 2")
    }

    @Test("Out and Low chips are hidden when their count is zero")
    func hiddenChips() {
        #expect(StockListModel(products: sample).visibleFilters == [.all, .out, .low])
        #expect(StockListModel(products: [product("Milk", .full), product("Eggs", .low)]).visibleFilters == [.all, .low])
        #expect(StockListModel(products: []).visibleFilters == [.all])
    }

    @Test("tapping the selected chip returns to All")
    func toggle() {
        #expect(StockListModel.toggled(.all, tapped: .out) == .out)
        #expect(StockListModel.toggled(.out, tapped: .low) == .low)
        #expect(StockListModel.toggled(.low, tapped: .low) == .all)
        #expect(StockListModel.toggled(.all, tapped: .all) == .all)
    }

    @Test("a chip filter keeps only products at that level")
    func filterByChip() {
        #expect(names(StockListModel(products: sample, filter: .out)) == ["Bleach", "Soap"])
        #expect(names(StockListModel(products: sample, filter: .low)) == ["Apples", "Eggs"])
    }

    @Test("a filter whose chip is hidden falls back to All")
    func staleFilterFallsBack() {
        let model = StockListModel(products: [product("Milk", .full)], filter: .out)
        #expect(model.effectiveFilter == .all)
        #expect(names(model) == ["Milk"])
    }

    @Test("search matches names ignoring case, diacritics and surrounding spaces")
    func search() {
        #expect(names(StockListModel(products: sample, query: "cafe")) == ["Café"])
        #expect(names(StockListModel(products: sample, query: "  EGG ")) == ["Eggs"])
        #expect(StockListModel(products: sample, query: "zzz").groups.isEmpty)
    }

    @Test("search and chip filter combine")
    func searchAndFilter() {
        #expect(names(StockListModel(products: sample, filter: .low, query: "app")) == ["Apples"])
    }

    @Test("groups follow ProductCategory order, then Uncategorized, skipping empty ones")
    func grouping() {
        let groups = StockListModel(products: sample).groups
        #expect(groups.map(\.category) == [.food, .cleaning, .hygiene, nil])
        #expect(groups.map(\.title) == ["Food", "Cleaning", "Hygiene", "Uncategorized"])
        #expect(groups.map(\.icon) == ["fork.knife", "bubbles.and.sparkles", "hands.and.sparkles", "tray"])
        #expect(groups.map(\.id) == ["food", "cleaning", "hygiene", "uncategorized"])
    }

    @Test("rows sort by level ascending, then name")
    func sortOrder() {
        let food = StockListModel(products: sample).groups.first
        #expect(food?.products.map(\.name) == ["Apples", "Eggs", "Café", "Milk"])
    }

    // MARK: - Category filter

    @Test("a category chip keeps only products in that category")
    func filterByCategory() {
        let model = StockListModel(products: sample, category: .food)
        #expect(model.groups.count == 1)
        #expect(names(model) == ["Apples", "Eggs", "Café", "Milk"])
        #expect(names(StockListModel(products: sample, category: .hygiene)) == ["Soap"])
    }

    @Test("category counts stay stable: they ignore the active level filter")
    func categoryCountsAreLevelBlind() {
        let all = StockListModel(products: sample)
        #expect(all.count(for: .food) == 4)
        #expect(all.title(for: .food) == "Food 4")

        let out = StockListModel(products: sample, filter: .out)
        #expect(out.count(for: .food) == 4)
        #expect(out.title(for: .cleaning) == "Cleaning 1")
    }

    @Test("level counts are faceted by the active category")
    func levelCountsFollowCategory() {
        let food = StockListModel(products: sample, category: .food)
        #expect(food.count(for: .all) == 4)
        #expect(food.count(for: .out) == 0)
        #expect(food.count(for: .low) == 2)
        #expect(food.visibleFilters == [.all, .low])
    }

    @Test("only categories that hold products get a chip, and the level filter never moves them")
    func visibleCategories() {
        #expect(StockListModel(products: sample).visibleCategories == [.food, .cleaning, .hygiene])
        #expect(StockListModel(products: sample, filter: .out).visibleCategories == [.food, .cleaning, .hygiene])
        #expect(StockListModel(products: []).visibleCategories == [])
    }

    @Test("a category holding nothing falls back to all categories")
    func staleCategoryFallsBack() {
        let model = StockListModel(products: sample, category: .other)
        #expect(model.effectiveCategory == nil)
        #expect(model.groups.map(\.category) == [.food, .cleaning, .hygiene, nil])
    }

    @Test("a level with no products in the chosen category falls back to All within it")
    func staleLevelInsideCategory() {
        let model = StockListModel(products: sample, filter: .out, category: .food)
        #expect(model.effectiveFilter == .all)
        #expect(names(model) == ["Apples", "Eggs", "Café", "Milk"])
    }

    @Test("category, level and search all combine")
    func categoryLevelAndSearch() {
        let model = StockListModel(products: sample, filter: .low, category: .food, query: "app")
        #expect(names(model) == ["Apples"])
    }
}
