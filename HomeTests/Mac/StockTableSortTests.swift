#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("Stock table sort") @MainActor struct StockTableSortTests {
    private let apple = StockProduct(name: "apple", level: .full, supermarket: .mercadona, category: .food)
    private let banana = StockProduct(name: "Banana", level: .out, category: .cleaning)
    private let cherry = StockProduct(name: "cherry", level: .low, supermarket: .carrefour)

    @Test("name sorts case-insensitively like Finder")
    func byName() {
        let sorted = [cherry, banana, apple].sorted(using: KeyPathComparator(\StockProduct.name, comparator: .localizedStandard))
        #expect(sorted.map(\.name) == ["apple", "Banana", "cherry"])
    }

    @Test("level sorts out < low < full, and reverses")
    func byLevel() {
        #expect([apple, banana, cherry].sorted(using: KeyPathComparator(\StockProduct.level)).map(\.name) == ["Banana", "cherry", "apple"])
        #expect([apple, banana, cherry].sorted(using: KeyPathComparator(\StockProduct.level, order: .reverse)).map(\.name) == ["apple", "cherry", "Banana"])
    }

    @Test("products without a category or supermarket sort first ascending")
    func blanksFirst() {
        #expect([apple, banana, cherry].sorted(using: KeyPathComparator(\StockProduct.categorySortKey)).map(\.name) == ["cherry", "Banana", "apple"])
        #expect([apple, banana, cherry].sorted(using: KeyPathComparator(\StockProduct.supermarketSortKey)).map(\.name) == ["Banana", "cherry", "apple"])
    }
}
#endif
