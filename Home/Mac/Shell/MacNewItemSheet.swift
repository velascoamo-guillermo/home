#if os(macOS)
import SwiftUI

struct MacNewItemSheet: View {
    let action: MacPendingAction
    let budgetMonth: BudgetMonth
    @Environment(SupabaseStore.self) private var store
    @AppStorage(ExpenseDraft.lastPayerKey) private var lastPayerId = ""

    var body: some View {
        switch action {
        case .newTask:         HouseholdTaskSheet()
        case .newShoppingItem: MacNewShoppingItemSheet()
        case .newProduct:      AddStockProductSheet()
        case .newMeal:         MealFormSheet(existing: nil)
        case .newPet:          AddPetSheet()
        case .newAppointment(let petID): AddAppointmentSheet(petId: petID)
        case .newPetEvent(let petID):    AddEventSheet(petId: petID)
        case .importFiles:               EmptyView()
        case .newExpense:
            AddExpenseSheet(draft: ExpenseDraft(
                payerId: ExpenseDraft.defaultPayer(stored: lastPayerId, members: store.budgetMembers),
                date: ExpenseDraft.defaultDate(viewing: budgetMonth, today: .now, calendar: .current)))
        }
    }
}
#endif
