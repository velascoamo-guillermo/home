#if os(macOS)
import SwiftUI

struct MacDetailView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store

    var body: some View {
        switch model.selection {
        case .today:    MacTodayView(model: model)
        case .tasks:    NavigationStack { TasksView() }
        case .shopping: NavigationStack { ShoppingView() }
        case .stock:    NavigationStack { StockView() }
        case .meals:    NavigationStack { MenuView() }
        case .budget:   NavigationStack { BudgetView() }
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
