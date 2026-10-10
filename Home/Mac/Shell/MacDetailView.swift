#if os(macOS)
import SwiftUI

struct MacDetailView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store

    var body: some View {
        switch model.selection {
        case .today:    MacTodayView(model: model)
        case .tasks:    MacTasksView(model: model)
        case .shopping: MacShoppingView(model: model)
        case .stock:    MacStockView(model: model)
        case .meals:    MacMealsView(model: model)
        case .budget:   MacBudgetView(model: model)
        case .pet(let id):
            if let pet = store.pets.first(where: { $0.id == id }) {
                NavigationStack { PetDetailView(pet: pet) }
                    .id(id)
            } else {
                ContentUnavailableView("No Pet Selected", systemImage: "pawprint")
            }
        }
    }
}
#endif
