#if os(macOS)
import Foundation

enum CommandRouter {
    /// The row a Go command lands on, or nil when it has nowhere to go (the menu item dims).
    static func destination(for target: GoTarget, current: SidebarItem, pets: [Pet]) -> SidebarItem? {
        switch target {
        case .today:    return .today
        case .tasks:    return .tasks
        case .shopping: return .shopping
        case .stock:    return .stock
        case .meals:    return .meals
        case .budget:   return .budget
        case .pets:
            if case .pet(let id) = current, pets.contains(where: { $0.id == id }) { return current }
            return SidebarModel.petRows(pets).first.map { .pet($0.id) }
        }
    }

    /// Where a File ▸ New command shows its result; nil keeps the current selection.
    static func destination(for action: MacPendingAction, current: SidebarItem) -> SidebarItem? {
        switch action {
        case .newTask:         .tasks
        case .newExpense:      .budget
        case .newShoppingItem: .shopping
        case .newProduct:      .stock
        case .newMeal:         .meals
        case .newPet:          nil
        }
    }

    static func primaryAction(on item: SidebarItem) -> MacPendingAction? {
        switch item {
        case .today, .tasks: .newTask
        case .shopping:      .newShoppingItem
        case .stock:         .newProduct
        case .meals:         .newMeal
        case .budget:        .newExpense
        case .pet:           nil
        }
    }

    static func hasInspector(on item: SidebarItem) -> Bool {
        switch item {
        case .today, .tasks, .stock, .meals, .budget: true
        case .shopping, .pet:                         false
        }
    }
}
#endif
