import SwiftUI

enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case tasks, pets, stock, meals, shopping

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:    "Tasks"
        case .pets:     "Pets"
        case .stock:    "Stock"
        case .meals:    "Meals"
        case .shopping: "Shopping"
        }
    }

    var systemImage: String {
        switch self {
        case .tasks:    "checklist"
        case .pets:     "pawprint.fill"
        case .stock:    "shippingbox.fill"
        case .meals:    "fork.knife"
        case .shopping: "cart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .tasks:    .blue
        case .pets:     .pink
        case .stock:    .purple
        case .meals:    .orange
        case .shopping: .green
        }
    }

    var appTab: AppTab {
        switch self {
        case .tasks:    .tasks
        case .pets:     .pets
        case .stock:    .stock
        case .meals:    .meals
        case .shopping: .shopping
        }
    }

    init?(appTab: AppTab) {
        switch appTab {
        case .tasks:    self = .tasks
        case .pets:     self = .pets
        case .stock:    self = .stock
        case .meals:    self = .meals
        case .shopping: self = .shopping
        default:        return nil
        }
    }
}
