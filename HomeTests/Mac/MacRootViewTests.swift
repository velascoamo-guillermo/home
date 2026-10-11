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

    @Test("menu enablement must read the live availableCommands value, not a stale pre-change snapshot")
    func featureChangeClearsRequestableCommands() {
        // `macWindow` holds a stable `MacWindowModel` reference across a feature/selection
        // change, so a `Commands` menu keyed only on that reference (mutated in place) can go
        // stale until some unrelated focus change forces SwiftUI to re-evaluate it. The fix
        // (`FocusedValues.macAvailableCommands`, mirrored by `MacRootView` from
        // `model.availableCommands` on every render) means `MacAppCommands` must always be fed
        // the *current* value, never a snapshot taken before the change. `isCommandEnabled` is
        // the pure decision `MacAppCommands` makes from whatever `Set` it is handed — this test
        // feeds it both the live, post-change value and the stale pre-change snapshot to prove
        // the two disagree, so swapping the fresh feed back for a stale one (i.e. reverting to
        // reading `window?.availableCommands` directly) would flip these assertions.
        let model = MacWindowModel(selection: .tasks)
        model.availableCommands = [.markDone]
        let staleSnapshot = model.availableCommands

        model.selection = .budget

        #expect(!MacAppCommands.isCommandEnabled(.markDone, availableCommands: model.availableCommands))
        #expect(MacAppCommands.isCommandEnabled(.markDone, availableCommands: staleSnapshot))
    }
}
#endif
