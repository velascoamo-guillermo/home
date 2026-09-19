import Foundation

struct MealEntry: Identifiable, Hashable {
    struct Link: Hashable {
        var product: StockProduct
    }

    var menuEntry: MenuEntry
    var meal: Meal
    var links: [Link]

    var id: UUID { menuEntry.id }

    nonisolated var isShort: Bool {
        !shortLinks.isEmpty
    }

    nonisolated var shortLinks: [Link] {
        links.filter { $0.product.level == .out }
    }

    nonisolated var allShortNeeded: Bool {
        let short = shortLinks
        return !short.isEmpty && short.allSatisfy { $0.product.needed }
    }
}
