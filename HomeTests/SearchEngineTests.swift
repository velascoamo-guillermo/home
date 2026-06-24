import Testing
import Foundation
@testable import Home

@Suite("SearchEngine") @MainActor struct SearchEngineTests {

    private func stock(_ name: String) -> StockProduct {
        StockProduct(name: name, icon: "x", packages: 1, looseUnits: 0, unitsPerPackage: 6)
    }
    private func task(_ title: String) -> HouseholdTask {
        HouseholdTask(title: title, icon: "x", intervalDays: 7, nextDueDate: .now)
    }
    private func meal(_ title: String) -> Meal {
        Meal(dayOfWeek: 0, slot: .lunch, title: title)
    }
    private func pet(_ name: String) -> Pet {
        Pet(name: name, type: "Dog", breed: "Lab")
    }

    @Test("empty query returns no results")
    func emptyQuery() {
        let r = SearchEngine.search(query: "  ", stock: [stock("Milk")],
                                    tasks: [], meals: [], pets: [])
        #expect(r.isEmpty)
    }

    @Test("matches across all four types, case- and diacritic-insensitive")
    func matchesAllTypes() {
        let r = SearchEngine.search(
            query: "ca",
            stock: [stock("Café"), stock("Milk")],
            tasks: [task("Cambiar arena"), task("Vacuum")],
            meals: [meal("Carbonara"), meal("Pizza")],
            pets: [pet("Cacao"), pet("Rex")]
        )
        #expect(r.stock.map(\.name) == ["Café"])
        #expect(r.tasks.map(\.title) == ["Cambiar arena"])
        #expect(r.meals.map(\.title) == ["Carbonara"])
        #expect(r.pets.map(\.name) == ["Cacao"])
        #expect(!r.isEmpty)
    }

    @Test("no match yields empty, non-nil results")
    func noMatch() {
        let r = SearchEngine.search(query: "zzz", stock: [stock("Milk")],
                                    tasks: [task("Vacuum")], meals: [meal("Pizza")],
                                    pets: [pet("Rex")])
        #expect(r.isEmpty)
    }
}
