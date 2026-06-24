import Testing
import Foundation
@testable import Home

@Suite("DashboardConfig") struct DashboardConfigTests {

    @Test("default enables all four cards in catalog order")
    func defaultOrder() {
        #expect(DashboardConfig.default.cards == DashboardCard.allCases)
        #expect(DashboardConfig.default.cards == [.upcomingTasks, .shoppingList, .weekMeals, .appointments])
    }

    @Test("disabling removes from cards and surfaces in disabledCards")
    func disable() {
        var c = DashboardConfig.default
        c.setEnabled(.weekMeals, false)
        #expect(!c.cards.contains(.weekMeals))
        #expect(c.disabledCards == [.weekMeals])
    }

    @Test("enabling appends; enabling twice does not duplicate")
    func enableNoDuplicate() {
        var c = DashboardConfig(cards: [.upcomingTasks])
        c.setEnabled(.appointments, true)
        c.setEnabled(.appointments, true)
        #expect(c.cards == [.upcomingTasks, .appointments])
    }

    @Test("move reorders enabled cards")
    func move() {
        var c = DashboardConfig.default
        c.move(fromOffsets: IndexSet(integer: 0), toOffset: 4)
        #expect(c.cards == [.shoppingList, .weekMeals, .appointments, .upcomingTasks])
    }

    @Test("Codable round-trips")
    func codable() throws {
        let c = DashboardConfig(cards: [.appointments, .upcomingTasks])
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(DashboardConfig.self, from: data)
        #expect(back == c)
    }

    @Test("deepLinkHost: tasks stay on Home, others route")
    func deepLinkHosts() {
        #expect(DashboardCard.upcomingTasks.deepLinkHost == nil)
        #expect(DashboardCard.shoppingList.deepLinkHost == "shopping")
        #expect(DashboardCard.weekMeals.deepLinkHost == "meals")
        #expect(DashboardCard.appointments.deepLinkHost == "pets")
    }
}
