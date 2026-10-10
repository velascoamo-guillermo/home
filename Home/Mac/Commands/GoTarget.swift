#if os(macOS)
import SwiftUI

enum GoTarget: Int, CaseIterable {
    case today = 1, tasks, shopping, stock, meals, budget, pets

    var title: String {
        switch self {
        case .today:    "Today"
        case .tasks:    "Tasks"
        case .shopping: "Shopping"
        case .stock:    "Stock"
        case .meals:    "Meals"
        case .budget:   "Budget"
        case .pets:     "Pets"
        }
    }

    var keyEquivalent: KeyEquivalent { KeyEquivalent(Character(String(rawValue))) }
}
#endif
