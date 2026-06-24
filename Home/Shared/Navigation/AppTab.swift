import Foundation

enum AppTab: String, Hashable {
    case home, pets, stock, meals, shopping, search, menu

    init?(host: String?) {
        switch host {
        case "home":     self = .home
        case "pets":     self = .pets
        case "stock":    self = .stock
        case "meals":    self = .meals
        case "shopping": self = .shopping
        case "search":   self = .search
        case "menu":     self = .menu
        default:         return nil
        }
    }
}
