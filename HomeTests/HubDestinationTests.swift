import Testing
@testable import Home

@Suite("HubDestination") @MainActor struct HubDestinationTests {

    @Test("allCases order is Pets, Stock, Meals, Shopping")
    func order() {
        #expect(HubDestination.allCases == [.pets, .stock, .meals, .shopping])
    }

    @Test("titles and icons are set")
    func metadata() {
        #expect(HubDestination.pets.title == "Pets")
        #expect(HubDestination.stock.title == "Stock")
        #expect(HubDestination.meals.title == "Meals")
        #expect(HubDestination.shopping.title == "Shopping")
        #expect(HubDestination.pets.systemImage == "pawprint.fill")
    }

    @Test("bridges to and from AppTab")
    func bridge() {
        #expect(HubDestination(appTab: .meals) == .meals)
        #expect(HubDestination(appTab: .home) == nil)
        #expect(HubDestination(appTab: .menu) == nil)
        #expect(HubDestination.shopping.appTab == .shopping)
    }
}
