import Testing
import SwiftUI
@testable import Casita

@Suite("DashboardCard fill") @MainActor struct DashboardCardFillTests {

    @Test("each card maps to its feature pastel")
    func fills() {
        #expect(DashboardCard.upcomingTasks.fill == Palette.tasks)
        #expect(DashboardCard.shoppingList.fill == Palette.shopping)
        #expect(DashboardCard.weekMeals.fill == Palette.meals)
        #expect(DashboardCard.appointments.fill == Palette.pets)
    }
}
