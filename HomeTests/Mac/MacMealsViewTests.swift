#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("MacMealsView") @MainActor struct MacMealsViewTests {

    @Test("Suggest Week needs an empty slot and at least one titled meal")
    func canSuggest() {
        let titled = Meal(title: "Lentejas")
        let untitled = Meal(title: "")
        #expect(MacMealsView.canSuggest(emptySlotCount: 3, meals: [titled]))
        #expect(!MacMealsView.canSuggest(emptySlotCount: 0, meals: [titled]))
        #expect(!MacMealsView.canSuggest(emptySlotCount: 3, meals: [untitled]))
        #expect(!MacMealsView.canSuggest(emptySlotCount: 3, meals: []))
    }
}
#endif
