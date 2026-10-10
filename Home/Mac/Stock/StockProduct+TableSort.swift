#if os(macOS)
// `ProductCategory.displayName`/`Supermarket.displayName` are MainActor-isolated
// (project default actor isolation), which makes a `KeyPath` built from them
// non-Sendable and unusable with `Table`'s `KeyPathComparator`. `rawValue` is
// compiler-synthesized and nonisolated, and sorts in the same relative order
// for this fixed set of cases, so it's used here instead.
nonisolated extension StockProduct {
    var categorySortKey: String { category?.rawValue ?? "" }
    var supermarketSortKey: String { supermarket?.rawValue ?? "" }
}
#endif
