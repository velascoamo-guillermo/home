#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("Mac shopping") @MainActor struct ShoppingGroupingTests {

    @Test("items group by supermarket in enum order, unassigned last, empty groups omitted")
    func grouping() {
        let milk = StockProduct(name: "Milk", level: .out, supermarket: .mercadona)
        let soap = StockProduct(name: "Soap", level: .low)
        let rice = StockProduct(name: "Rice", level: .out, supermarket: .carrefour)
        let groups = ShoppingGrouping.groups([milk, soap, rice])
        #expect(groups.map(\.title) == ["Carrefour", "Mercadona", "Unassigned"])
        #expect(groups.map { $0.products.map(\.name) } == [["Rice"], ["Milk"], ["Soap"]])
        #expect(ShoppingGrouping.groups([milk]).map(\.title) == ["Mercadona"])
    }

    @Test("Mark as Bought needs a selection; Finish Shopping needs a checked item")
    func commands() {
        #expect(MacShoppingView.commands(hasSelection: false, checkedCount: 0).isEmpty)
        #expect(MacShoppingView.commands(hasSelection: true, checkedCount: 0) == [.markBought])
        #expect(MacShoppingView.commands(hasSelection: false, checkedCount: 2) == [.finishShopping])
        #expect(MacShoppingView.commands(hasSelection: true, checkedCount: 1) == [.markBought, .finishShopping])
    }

    @Test("Failed names accumulate across calls, keep order, and never duplicate")
    func mergeFailedNames() {
        #expect(MacShoppingView.mergeFailedNames([], adding: ["Milk"]) == ["Milk"])
        #expect(MacShoppingView.mergeFailedNames(["Milk"], adding: ["Soap"]) == ["Milk", "Soap"])
        #expect(MacShoppingView.mergeFailedNames(["Milk"], adding: ["Milk", "Soap"]) == ["Milk", "Soap"])
        #expect(MacShoppingView.mergeFailedNames(["Milk", "Soap"], adding: []) == ["Milk", "Soap"])
    }
}
#endif
