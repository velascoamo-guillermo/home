import Testing
import SwiftUI
@testable import Casita

@Suite("DashboardCard tint") struct DashboardCardTintTests {

    @Test("each card carries its designed accent color")
    func tints() {
        #expect(DashboardCard.upcomingTasks.tint == .blue)
        #expect(DashboardCard.shoppingList.tint == .green)
        #expect(DashboardCard.weekMeals.tint == .orange)
        #expect(DashboardCard.appointments.tint == .pink)
    }
}
