import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct UITestSupportTests {
    @Test func makeStoreLoadsOfflineWithoutSync() async {
        let store = UITestSupport.makeStore()
        await store.loadAll()
        #expect(store.loadError == nil)
        #expect(store.isLoading == false)
        #expect(store._sync == nil)
        #expect(store.stockProducts.isEmpty)
    }

    @Test func seedCreatesFixtures() async {
        let store = UITestSupport.makeStore()
        await store.loadAll()
        await UITestSupport.seed(store)

        #expect(store.stockProducts.count == 3)
        #expect(store.householdTasks.count == 2)

        let filters = store.stockProducts.first { $0.name == "Fixture Filters" }
        #expect(filters?.totalUnits == 0)
        #expect(store.shoppingList.map(\.name) == ["Fixture Filters"])

        let milk = store.stockProducts.first { $0.name == "Fixture Milk" }
        #expect(milk?.totalUnits == 12)

        let linked = store.householdTasks.first { $0.title == "Fixture Change Filter" }
        #expect(linked?.productId == filters?.id)
        #expect(linked.map { $0.nextDueDate < .now } == true)

        let future = store.householdTasks.first { $0.title == "Fixture Water Plants" }
        #expect(future?.productId == nil)
        #expect(future.map { $0.nextDueDate > .now } == true)
    }

    @Test func separateStoresAreIsolated() async {
        let a = UITestSupport.makeStore()
        await a.loadAll()
        await UITestSupport.seed(a)
        let b = UITestSupport.makeStore()
        await b.loadAll()
        #expect(b.stockProducts.isEmpty)
    }
}
