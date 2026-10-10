#if os(macOS)
import Foundation

enum MacPendingAction: Hashable, Identifiable, Sendable {
    case newTask, newExpense, newShoppingItem, newProduct, newMeal, newPet
    case newAppointment(petID: UUID)
    case newPetEvent(petID: UUID)
    case importFiles(petID: UUID)

    var id: Self { self }

    var title: String {
        switch self {
        case .newTask:         "New Task"
        case .newExpense:      "New Expense"
        case .newShoppingItem: "New Shopping Item"
        case .newProduct:      "New Product"
        case .newMeal:         "New Meal"
        case .newPet:          "New Pet…"
        case .newAppointment:  "New Appointment"
        case .newPetEvent:     "New Event"
        case .importFiles:     "Import…"
        }
    }

    /// Import runs through the system Open panel on the pet detail, not a sheet.
    var presentsSheet: Bool {
        if case .importFiles = self { return false }
        return true
    }
}
#endif
