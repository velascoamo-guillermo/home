import Testing
import SwiftUI
@testable import Casita

@Suite("Hub tiles") @MainActor struct HubTileTests {

    @Test("all contains one tile per destination plus settings")
    func tileCount() {
        #expect(HubTile.all.count == HubDestination.allCases.count + 1)
    }

    @Test("destination tiles keep HubDestination order, settings last")
    func order() {
        let titles = HubTile.all.map(\.title)
        #expect(Array(titles.prefix(5)) == ["Tasks", "Pets", "Stock", "Meals", "Shopping"])
        #expect(titles.last == "Settings")
    }

    @Test("every tile title is unique")
    func uniqueTitles() {
        let titles = HubTile.all.map(\.title)
        #expect(Set(titles).count == titles.count)
    }

    @Test("settings tile uses gearshape.fill and surface fill")
    func settingsTile() {
        #expect(HubTile.settings.title == "Settings")
        #expect(HubTile.settings.systemImage == "gearshape.fill")
        #expect(HubTile.settings.fill == Palette.surface)
    }

    @Test("destination tiles delegate fill to HubDestination")
    func destinationFills() {
        #expect(HubTile.destination(.tasks).fill == Palette.tasks)
    }
}
