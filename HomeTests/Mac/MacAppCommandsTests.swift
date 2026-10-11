#if os(macOS)
import Testing
@testable import Casita

@Suite("MacAppCommands shellReady") @MainActor struct MacAppCommandsTests {
    @Test("Go, Inspector and Period items stay dimmed until a window exists and loading finishes")
    func shellReady() {
        let window = MacWindowModel(selection: .today)
        #expect(!MacAppCommands.shellReady(window: nil, didFinishLoading: false))
        #expect(!MacAppCommands.shellReady(window: nil, didFinishLoading: true))
        #expect(!MacAppCommands.shellReady(window: window, didFinishLoading: false))
        #expect(MacAppCommands.shellReady(window: window, didFinishLoading: true))
    }
}
#endif
