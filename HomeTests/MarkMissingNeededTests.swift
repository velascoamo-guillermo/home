import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct MarkMissingNeededTests {
    private func product(name: String, units: Int, needed: Bool = false) -> StockProduct {
        var p = StockProduct(name: name, icon: "shippingbox",
                             packages: 0, looseUnits: units, unitsPerPackage: 1)
        p.needed = needed
        return p
    }

    private func entry(links: [MealEntry.Link]) -> MealEntry {
        MealEntry(menuEntry: MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: UUID()),
                  meal: Meal(title: "Test"),
                  links: links)
    }

    @Test func shortLinksAreExactlyTheInsufficientOnes() {
        let short = product(name: "Short", units: 1)
        let fine = product(name: "Fine", units: 5)
        let e = entry(links: [.init(product: short, quantity: 3),
                              .init(product: fine, quantity: 2)])
        #expect(e.shortLinks.map(\.product.name) == ["Short"])
        #expect(e.allShortNeeded == false)
    }

    @Test func allShortNeededTrueOnlyWhenEveryShortIsNeeded() {
        let shortNeeded = product(name: "A", units: 1, needed: true)
        let e = entry(links: [.init(product: shortNeeded, quantity: 3)])
        #expect(e.allShortNeeded == true)
        let notShort = entry(links: [.init(product: product(name: "B", units: 5), quantity: 1)])
        #expect(notShort.allShortNeeded == false)
    }

    @Test func markMissingNeededMarksOnlyShortProducts() async throws {
        let store = SupabaseStore.makeTest()
        let short = product(name: "Short", units: 1)
        let fine = product(name: "Fine", units: 5)
        store.stockProducts = [short, fine]
        let e = entry(links: [.init(product: short, quantity: 3),
                              .init(product: fine, quantity: 2)])

        await store.markMissingNeeded(for: e)

        #expect(store.stockProducts.first { $0.id == short.id }?.needed == true)
        #expect(store.stockProducts.first { $0.id == fine.id }?.needed == false)
    }

    @Test func markMissingNeededIsIdempotent() async throws {
        let store = SupabaseStore.makeTest()
        let short = product(name: "Short", units: 1, needed: true)
        store.stockProducts = [short]
        let e = entry(links: [.init(product: short, quantity: 3)])

        await store.markMissingNeeded(for: e)

        #expect(store.stockProducts.first { $0.id == short.id }?.needed == true)
    }
}
