#if os(macOS)
enum ShoppingGrouping {
    static func groups(_ list: [StockProduct]) -> [ShoppingGroup] {
        var result: [ShoppingGroup] = Supermarket.allCases.compactMap { market in
            let items = list.filter { $0.supermarket == market }
            guard !items.isEmpty else { return nil }
            return ShoppingGroup(id: market.rawValue, title: market.displayName, products: items)
        }
        let unassigned = list.filter { $0.supermarket == nil }
        if !unassigned.isEmpty {
            result.append(ShoppingGroup(id: "unassigned", title: "Unassigned", products: unassigned))
        }
        return result
    }
}
#endif
