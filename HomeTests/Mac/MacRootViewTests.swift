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
}
#endif
