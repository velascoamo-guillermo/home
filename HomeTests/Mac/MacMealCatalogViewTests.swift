#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("MacMealCatalogView") @MainActor struct MacMealCatalogViewTests {
    @Test("the selected meal is looked up by id, like the other Mac lists")
    func selectedMeal() {
        let lentejas = Meal(title: "Lentejas")
        let paella = Meal(title: "Paella")
        let catalog = [lentejas, paella]
        #expect(MacMealCatalogView.meal(for: lentejas.id, in: catalog) == lentejas)
        #expect(MacMealCatalogView.meal(for: nil, in: catalog) == nil)
        #expect(MacMealCatalogView.meal(for: UUID(), in: catalog) == nil)
    }
}
#endif
