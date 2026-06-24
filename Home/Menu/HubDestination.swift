import Foundation

enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case pets, stock, meals, shopping

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pets:     "Pets"
        case .stock:    "Stock"
        case .meals:    "Meals"
        case .shopping: "Shopping"
        }
    }

    var systemImage: String {
        switch self {
        case .pets:     "pawprint.fill"
        case .stock:    "shippingbox.fill"
        case .meals:    "fork.knife"
        case .shopping: "cart.fill"
        }
    }

    var appTab: AppTab {
        switch self {
        case .pets:     .pets
        case .stock:    .stock
        case .meals:    .meals
        case .shopping: .shopping
        }
    }

    init?(appTab: AppTab) {
        switch appTab {
        case .pets:     self = .pets
        case .stock:    self = .stock
        case .meals:    self = .meals
        case .shopping: self = .shopping
        default:        return nil
        }
    }
}
