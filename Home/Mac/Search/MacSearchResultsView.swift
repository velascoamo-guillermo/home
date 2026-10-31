#if os(macOS)
import SwiftUI

struct MacSearchResultsView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @State private var selection: SearchSelection?
    @State private var productToDelete: StockProduct?

    private var results: SearchResults {
        SearchEngine.search(query: model.searchText, stock: store.stockProducts,
                            tasks: store.householdTasks, meals: store.meals, pets: store.pets)
    }

    var body: some View {
        Group {
            if results.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                List {
                    if !results.stock.isEmpty {
                        Section("Stock") {
                            ForEach(results.stock) { product in
                                Button { selection = .stock(product) } label: {
                                    HStack(spacing: 12) {
                                        CategoryGlyph(systemImage: HubDestination.stock.systemImage, fill: HubDestination.stock.fill)
                                        StockProductRow(product: product)
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .surfaceRow()
                                .contextMenu { StockContextMenu(product: product, onDeleteRequest: { productToDelete = $0 }) }
                            }
                        }
                    }
                    if !results.tasks.isEmpty {
                        Section("Tasks") {
                            ForEach(results.tasks) { task in
                                Button { selection = .task(task) } label: {
                                    HStack(spacing: 12) {
                                        CategoryGlyph(systemImage: HubDestination.tasks.systemImage, fill: HubDestination.tasks.fill)
                                        SearchTaskRow(task: task)
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .surfaceRow()
                                .contextMenu { TaskContextMenu(task: task) }
                            }
                        }
                    }
                    if !results.meals.isEmpty {
                        Section("Meals") {
                            ForEach(results.meals) { meal in
                                Button { selection = .meal(meal) } label: {
                                    HStack(spacing: 12) {
                                        CategoryGlyph(systemImage: HubDestination.meals.systemImage, fill: HubDestination.meals.fill)
                                        SearchMealRow(meal: meal)
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .surfaceRow()
                            }
                        }
                    }
                    if !results.pets.isEmpty {
                        Section("Pets") {
                            ForEach(results.pets) { pet in
                                Button {
                                    model.searchText = ""
                                    model.selection = .pet(pet.id)
                                } label: { PetRow(pet: pet) }
                                .buttonStyle(.plain)
                                .surfaceRow()
                            }
                        }
                    }
                }
                .flatListStyle()
            }
        }
        .gradientCanvas()
        .sheet(item: $selection) { selected in
            switch selected {
            case .stock(let product): AddStockProductSheet(existing: product)
            case .task(let task):     HouseholdTaskSheet(existing: task)
            case .meal(let meal):     MealFormSheet(existing: meal)
            }
        }
        .productDeleteDialog($productToDelete)
    }
}
#endif
