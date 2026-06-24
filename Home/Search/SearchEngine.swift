import Foundation

struct SearchResults {
    var stock: [StockProduct] = []
    var tasks: [HouseholdTask] = []
    var meals: [Meal] = []
    var pets: [Pet] = []

    var isEmpty: Bool {
        stock.isEmpty && tasks.isEmpty && meals.isEmpty && pets.isEmpty
    }
}

enum SearchEngine {
    static func search(
        query: String,
        stock: [StockProduct],
        tasks: [HouseholdTask],
        meals: [Meal],
        pets: [Pet]
    ) -> SearchResults {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return SearchResults() }
        func matches(_ s: String) -> Bool { s.localizedStandardContains(q) }
        return SearchResults(
            stock: stock.filter { matches($0.name) },
            tasks: tasks.filter { matches($0.title) },
            meals: meals.filter { matches($0.title) },
            pets: pets.filter { matches($0.name) }
        )
    }
}
