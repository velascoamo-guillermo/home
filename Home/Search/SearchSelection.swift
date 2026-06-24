import Foundation

enum SearchSelection: Identifiable {
    case stock(StockProduct)
    case task(HouseholdTask)
    case meal(Meal)

    var id: UUID {
        switch self {
        case .stock(let p): p.id
        case .task(let t):  t.id
        case .meal(let m):  m.id
        }
    }
}
