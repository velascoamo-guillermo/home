import Testing
import SwiftUI
@testable import Casita

private enum Fruit: String, CaseIterable, Identifiable, Hashable {
    case apple, banana, cherry

    var id: String { rawValue }
}

@Suite("ChipGroup selection") @MainActor struct ChipGroupSelectionTests {

    @Test("required selection replaces current with tapped")
    func requiredSelect() {
        let result = ChipSelection.next(current: Fruit.apple, tapped: Fruit.banana)
        #expect(result == .banana)
    }

    @Test("required re-tap on the same item is a no-op")
    func requiredRetapIsNoOp() {
        let result = ChipSelection.next(current: Fruit.apple, tapped: Fruit.apple)
        #expect(result == .apple)
    }

    @Test("optional selection sets tapped from nil")
    func optionalSelect() {
        let result = ChipSelection.next(current: Optional<Fruit>.none, tapped: Fruit.banana)
        #expect(result == .banana)
    }

    @Test("optional re-tap on the selected item deselects")
    func optionalRetapDeselects() {
        let result = ChipSelection.next(current: Optional(Fruit.banana), tapped: Fruit.banana)
        #expect(result == nil)
    }

    @Test("optional switch replaces current selection with tapped")
    func optionalSwitch() {
        let result = ChipSelection.next(current: Optional(Fruit.apple), tapped: Fruit.banana)
        #expect(result == .banana)
    }

    @Test("ChipGroup preserves the order of the items passed in")
    func orderPreserved() {
        let input = Array(Fruit.allCases)
        let group = ChipGroup(
            items: input,
            selection: .constant(Fruit.apple),
            fill: Palette.pets,
            title: { $0.rawValue }
        )
        #expect(group.items == input)
    }
}
