#if os(macOS)
import Testing
@testable import Casita

@Suite("Mac settings") @MainActor struct MacSettingsTests {

    @Test("panes are titled for the window title and ordered Calendars, Sync")
    func panes() {
        #expect(MacSettingsPane.allCases.map(\.title) == ["Calendars", "Sync"])
        #expect(MacSettingsPane(rawValue: "sync") == .sync)
    }

    @Test("pending uploads read as a short phrase")
    func pendingDescription() {
        #expect(MacSyncSettingsPane.pendingDescription(0) == "Nothing waiting")
        #expect(MacSyncSettingsPane.pendingDescription(1) == "1 change")
        #expect(MacSyncSettingsPane.pendingDescription(4) == "4 changes")
    }
}
#endif
