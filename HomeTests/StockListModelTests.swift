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
}
