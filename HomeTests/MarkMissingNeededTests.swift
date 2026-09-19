import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct MarkMissingNeededTests {
    private func product(name: String, level: StockLevel, needed: Bool = false) -> StockProduct {
        StockProduct(name: name, level: level, needed: needed)
    }

    private func entry(_ products: [StockProduct]) -> MealEntry {
        MealEntry(menuEntry: MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: UUID()),
                  meal: Meal(title: "Test"),
                  links: products.map { MealEntry.Link(product: $0) })
    }

    @Test func shortLinksAreExactlyTheOutOnes() {
        let e = entry([product(name: "Out", level: .out),
                       product(name: "Low", level: .low),
                       product(name: "Full", level: .full)])
        #expect(e.shortLinks.map(\.product.name) == ["Out"])
        #expect(e.allShortNeeded == false)
    }

    @Test func allShortNeededTrueOnlyWhenEveryShortIsNeeded() {
        #expect(entry([product(name: "A", level: .out, needed: true)]).allShortNeeded == true)
        #expect(entry([product(name: "A", level: .out, needed: true),
                       product(name: "B", level: .out)]).allShortNeeded == false)
        #expect(entry([product(name: "C", level: .low)]).allShortNeeded == false)
    }

    @Test func markMissingNeededMarksOnlyShortProducts() async throws {
        let store = SupabaseStore.makeTest()
        let short = product(name: "Short", level: .out)
        let fine = product(name: "Fine", level: .low)
        store.stockProducts = [short, fine]

        await store.markMissingNeeded(for: entry([short, fine]))

        #expect(store.stockProducts.first { $0.id == short.id }?.needed == true)
        #expect(store.stockProducts.first { $0.id == fine.id }?.needed == false)
    }

    @Test func markMissingNeededIsIdempotent() async throws {
        let store = SupabaseStore.makeTest()
        let short = product(name: "Short", level: .out, needed: true)
        store.stockProducts = [short]

        await store.markMissingNeeded(for: entry([short]))

        #expect(store.stockProducts.first { $0.id == short.id }?.needed == true)
    }

    @Test func markMissingNeededDecidesFromCurrentStoreStateNotStaleEntrySnapshot() async throws {
        let store = SupabaseStore.makeTest()
        let current = product(name: "Short", level: .out, needed: false)
        store.stockProducts = [current]
        var stale = current
        stale.needed = true

        await store.markMissingNeeded(for: entry([stale]))

        #expect(store.stockProducts.first { $0.id == current.id }?.needed == true)
    }
}
