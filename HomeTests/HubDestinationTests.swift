import Testing
import SwiftUI
@testable import Casita

@Suite("HubDestination") @MainActor struct HubDestinationTests {

    @Test("allCases order is Tasks, Pets, Stock, Meals, Shopping, Budget")
    func order() {
        #expect(HubDestination.allCases == [.tasks, .pets, .stock, .meals, .shopping, .budget])
    }

    @Test("titles and icons are set")
    func metadata() {
        #expect(HubDestination.tasks.title == "Tasks")
        #expect(HubDestination.pets.title == "Pets")
        #expect(HubDestination.stock.title == "Stock")
        #expect(HubDestination.meals.title == "Meals")
        #expect(HubDestination.shopping.title == "Shopping")
        #expect(HubDestination.tasks.systemImage == "checklist")
        #expect(HubDestination.pets.systemImage == "pawprint.fill")
        #expect(HubDestination.budget.title == "Budget")
        #expect(HubDestination.budget.systemImage == "eurosign.circle.fill")
    }

    @Test("each destination maps to its feature pastel")
    func fills() {
        #expect(HubDestination.tasks.fill == Palette.tasks)
        #expect(HubDestination.pets.fill == Palette.pets)
        #expect(HubDestination.stock.fill == Palette.stock)
        #expect(HubDestination.meals.fill == Palette.meals)
        #expect(HubDestination.shopping.fill == Palette.shopping)
        #expect(HubDestination.budget.fill == Palette.budget)
    }

    @Test("bridges to and from AppTab")
    func bridge() {
        #expect(HubDestination(appTab: .tasks) == .tasks)
        #expect(HubDestination(appTab: .meals) == .meals)
        #expect(HubDestination(appTab: .home) == nil)
        #expect(HubDestination(appTab: .menu) == nil)
        #expect(HubDestination.tasks.appTab == .tasks)
        #expect(HubDestination.shopping.appTab == .shopping)
        #expect(HubDestination(appTab: .budget) == .budget)
        #expect(HubDestination.budget.appTab == .budget)
    }
}
