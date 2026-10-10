#if os(macOS)
import Testing
import SwiftUI
@testable import Casita

@Suite("MacRootView") @MainActor struct MacRootViewTests {
    @Test("the action-error alert is presented only in the key window")
    func presentsOnlyInKeyWindow() {
        #expect(MacRootView.shouldPresentActionError(controlActiveState: .key))
        #expect(!MacRootView.shouldPresentActionError(controlActiveState: .active))
        #expect(!MacRootView.shouldPresentActionError(controlActiveState: .inactive))
    }

    @Test("a feature change leaves nothing for a stale availableCommands snapshot to request")
    func featureChangeClearsRequestableCommands() {
        // `macWindow` holds a stable `MacWindowModel` reference across a feature/selection
        // change, so a `Commands` menu keyed only on that reference (mutated in place) can go
        // stale until some unrelated focus change forces SwiftUI to re-evaluate it. `MacAppCommands`
        // now also reads a dedicated `FocusedValues.macAvailableCommands` entry, mirrored by
        // `MacRootView` from `model.availableCommands` on every render, so the menu always sees
        // the current value. At the model layer, this is the invariant that mirror must preserve:
        // a stale snapshot taken just before a feature change must never still satisfy `request`.
        let model = MacWindowModel(selection: .tasks)
        model.availableCommands = [.markDone]
        let staleSnapshot = model.availableCommands

        model.selection = .budget

        #expect(model.availableCommands.isEmpty)
        #expect(!model.availableCommands.contains(where: staleSnapshot.contains))
    }
}
#endif
