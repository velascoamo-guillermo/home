import SwiftUI

enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case tasks, pets, stock, meals, shopping, budget

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:    "Tasks"
        case .pets:     "Pets"
        case .stock:    "Stock"
        case .meals:    "Meals"
        case .shopping: "Shopping"
        case .budget:   "Budget"
        }
    }

    var systemImage: String {
        switch self {
        case .tasks:    "checklist"
        case .pets:     "pawprint.fill"
        case .stock:    "shippingbox.fill"
        case .meals:    "fork.knife"
        case .shopping: "cart.fill"
        case .budget:   "eurosign.circle.fill"
        }
    }

    var fill: Color {
        switch self {
        case .tasks:    Palette.tasks
        case .pets:     Palette.pets
        case .stock:    Palette.stock
        case .meals:    Palette.meals
        case .shopping: Palette.shopping
        case .budget:   Palette.budget
        }
    }

    var appTab: AppTab {
        switch self {
        case .tasks:    .tasks
        case .pets:     .pets
        case .stock:    .stock
        case .meals:    .meals
        case .shopping: .shopping
        case .budget:   .budget
        }
    }

    init?(appTab: AppTab) {
        switch appTab {
        case .tasks:    self = .tasks
        case .pets:     self = .pets
        case .stock:    self = .stock
        case .meals:    self = .meals
        case .shopping: self = .shopping
        case .budget:   self = .budget
        default:        return nil
        }
    }
}
