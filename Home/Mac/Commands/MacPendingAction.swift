#if os(macOS)
import Foundation

enum MacPendingAction: Hashable, Identifiable, Sendable {
    case newTask, newExpense, newShoppingItem, newProduct, newMeal, newPet

    var id: Self { self }

    var title: String {
        switch self {
        case .newTask:         "New Task"
        case .newExpense:      "New Expense"
        case .newShoppingItem: "New Shopping Item"
        case .newProduct:      "New Product"
        case .newMeal:         "New Meal"
        case .newPet:          "New Pet…"
        }
    }
}
#endif
