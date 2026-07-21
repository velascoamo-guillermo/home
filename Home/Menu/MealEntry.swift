import Foundation

struct MealEntry: Identifiable, Hashable {
    struct Link: Hashable {
        var product: StockProduct
        var quantity: Int
    }

    var menuEntry: MenuEntry
    var meal: Meal
    var links: [Link]

    var id: UUID { menuEntry.id }

    nonisolated var isShort: Bool {
        links.contains { $0.product.totalUnits < $0.quantity }
    }
}
