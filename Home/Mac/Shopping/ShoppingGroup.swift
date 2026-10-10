#if os(macOS)
struct ShoppingGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let products: [StockProduct]
}
#endif
