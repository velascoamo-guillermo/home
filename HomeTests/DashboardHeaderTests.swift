import Testing
@testable import Casita

@Suite("DashboardHeaderView logic") @MainActor struct DashboardHeaderTests {

    @Test("greeting follows the hour of day")
    func greeting() {
        #expect(DashboardHeaderView.greeting(hour: 0) == "Good morning")
        #expect(DashboardHeaderView.greeting(hour: 11) == "Good morning")
        #expect(DashboardHeaderView.greeting(hour: 12) == "Good afternoon")
        #expect(DashboardHeaderView.greeting(hour: 17) == "Good afternoon")
        #expect(DashboardHeaderView.greeting(hour: 18) == "Good evening")
        #expect(DashboardHeaderView.greeting(hour: 23) == "Good evening")
    }

    @Test("summary joins non-zero segments with a middle dot")
    func summaryBoth() {
        #expect(DashboardHeaderView.summary(tasksDueToday: 3, itemsToBuy: 2) == "3 tasks today · 2 to buy")
    }

    @Test("summary singularizes one task and omits zero segments")
    func summaryEdges() {
        #expect(DashboardHeaderView.summary(tasksDueToday: 1, itemsToBuy: 0) == "1 task today")
        #expect(DashboardHeaderView.summary(tasksDueToday: 0, itemsToBuy: 4) == "4 to buy")
        #expect(DashboardHeaderView.summary(tasksDueToday: 0, itemsToBuy: 0) == nil)
    }
}
