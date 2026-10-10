#if os(macOS)
import Foundation

nonisolated enum SidebarItem: Hashable, Codable, Sendable {
    case today, tasks, shopping, stock, meals, budget
    case pet(UUID)

    static let household: [SidebarItem] = [.tasks, .shopping, .stock, .meals, .budget]

    var fixedTitle: String? {
        switch self {
        case .today:    "Today"
        case .tasks:    "Tasks"
        case .shopping: "Shopping"
        case .stock:    "Stock"
        case .meals:    "Meals"
        case .budget:   "Budget"
        case .pet:      nil
        }
    }

    var systemImage: String {
        switch self {
        case .today:    "sun.max"
        case .tasks:    "checklist"
        case .shopping: "cart"
        case .stock:    "shippingbox"
        case .meals:    "fork.knife"
        case .budget:   "eurosign.circle"
        case .pet:      "pawprint"
        }
    }
}
#endif
