import Foundation

struct StockListModel {
    enum Filter: Hashable, CaseIterable {
        case all, out, low
    }

    struct CategoryGroup: Identifiable, Hashable {
        let category: ProductCategory?
        let products: [StockProduct]

        var id: String { category?.rawValue ?? "uncategorized" }
        var title: String { category?.displayName ?? "Uncategorized" }
        var icon: String { category?.icon ?? "tray" }
    }

    let products: [StockProduct]
    var filter: Filter = .all
    var category: ProductCategory? = nil
    var query: String = ""

    // The category is the outer scope and the level the inner one: category counts
    // stay stable while level counts follow the chosen category. Letting both axes
    // count each other would make `effectiveFilter` and `effectiveCategory` recurse.

    func count(for filter: Filter) -> Int {
        inCategory.filter { Self.matches($0, filter: filter) }.count
    }

    func title(for filter: Filter) -> String {
        switch filter {
        case .all: "All \(count(for: .all))"
        case .out: "Out \(count(for: .out))"
        case .low: "Low \(count(for: .low))"
        }
    }

    var visibleFilters: [Filter] {
        Filter.allCases.filter { $0 == .all || count(for: $0) > 0 }
    }

    var effectiveFilter: Filter {
        visibleFilters.contains(filter) ? filter : .all
    }

    func count(for category: ProductCategory) -> Int {
        products.filter { $0.category == category }.count
    }

    func title(for category: ProductCategory) -> String {
        "\(category.displayName) \(count(for: category))"
    }

    var visibleCategories: [ProductCategory] {
        ProductCategory.allCases.filter { count(for: $0) > 0 }
    }

    var effectiveCategory: ProductCategory? {
        guard let category, visibleCategories.contains(category) else { return nil }
        return category
    }

    var groups: [CategoryGroup] {
        let active = effectiveFilter
        let visible = inCategory
            .filter { Self.matches($0, filter: active) && matchesQuery($0) }
            .sorted(by: Self.areInIncreasingOrder)
        let categories: [ProductCategory?] = ProductCategory.allCases.map(Optional.some) + [nil]
        return categories.compactMap { category in
            let items = visible.filter { $0.category == category }
            return items.isEmpty ? nil : CategoryGroup(category: category, products: items)
        }
    }

    static func toggled(_ current: Filter, tapped: Filter) -> Filter {
        current == tapped ? .all : tapped
    }

    private var inCategory: [StockProduct] {
        guard let category = effectiveCategory else { return products }
        return products.filter { $0.category == category }
    }

    private func matchesQuery(_ product: StockProduct) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || product.name.localizedStandardContains(q)
    }

    private static func matches(_ product: StockProduct, filter: Filter) -> Bool {
        switch filter {
        case .all: true
        case .out: product.level == .out
        case .low: product.level == .low
        }
    }

    private static func areInIncreasingOrder(_ a: StockProduct, _ b: StockProduct) -> Bool {
        if a.level != b.level { return a.level < b.level }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }
}
