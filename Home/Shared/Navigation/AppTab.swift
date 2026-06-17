import Foundation

enum AppTab: String, Hashable {
    case home, pets, stock, menu, shopping

    init?(host: String?) {
        switch host {
        case "home":     self = .home
        case "pets":     self = .pets
        case "stock":    self = .stock
        case "menu":     self = .menu
        case "shopping": self = .shopping
        default:         return nil
        }
    }
}
