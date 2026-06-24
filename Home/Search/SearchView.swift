import SwiftUI

struct SearchView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var searchText = ""
    @State private var selection: SearchSelection?

    private var results: SearchResults {
        SearchEngine.search(
            query: searchText,
            stock: store.stockProducts,
            tasks: store.householdTasks,
            meals: store.meals,
            pets: store.pets
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(
                        "Search",
                        systemImage: "magnifyingglass",
                        description: Text("Search stock, tasks, meals, pets.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        if !results.stock.isEmpty {
                            Section("Stock") {
                                ForEach(results.stock) { product in
                                    Button { selection = .stock(product) } label: {
                                        StockProductRow(product: product)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { stockMenu(product) }
                                }
                            }
                        }
                        if !results.tasks.isEmpty {
                            Section("Tasks") {
                                ForEach(results.tasks) { task in
                                    Button { selection = .task(task) } label: {
                                        SearchTaskRow(task: task)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { taskMenu(task) }
                                }
                            }
                        }
                        if !results.meals.isEmpty {
                            Section("Meals") {
                                ForEach(results.meals) { meal in
                                    Button { selection = .meal(meal) } label: {
                                        SearchMealRow(meal: meal)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { mealMenu(meal) }
                                }
                            }
                        }
                        if !results.pets.isEmpty {
                            Section("Pets") {
                                ForEach(results.pets) { pet in
                                    NavigationLink(value: pet) {
                                        PetRow(pet: pet)
                                    }
                                    .contextMenu { petMenu(pet) }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: Pet.self) { pet in
                PetDetailView(pet: pet)
            }
            .sheet(item: $selection) { sel in
                switch sel {
                case .stock(let p): AddStockProductSheet(existing: p)
                case .task(let t):  HouseholdTaskSheet(existing: t)
                case .meal(let m):
                    MealEditSheet(
                        dayOfWeek: m.dayOfWeek,
                        slot: m.slot,
                        entry: store.mealEntry(day: m.dayOfWeek, slot: m.slot)
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search stock, tasks, meals, pets")
        }
    }

    @ViewBuilder
    private func stockMenu(_ product: StockProduct) -> some View {
        Button {
            Task { try? await store.updateProduct(product.emptied()) }
        } label: { Label("Empty", systemImage: "trash.slash") }
        Button {
            Task { try? await store.replenish(product) }
        } label: { Label("Replenish", systemImage: "plus.square.on.square") }
        if let consumed = product.consumingOneUnit() {
            Button {
                Task { try? await store.updateProduct(consumed) }
            } label: { Label("Consume 1", systemImage: "minus.circle") }
        }
        Button(role: .destructive) {
            Task { try? await store.deleteProduct(product) }
        } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private func taskMenu(_ task: HouseholdTask) -> some View {
        Button {
            Task { try? await store.completeTask(task) }
        } label: { Label("Mark done", systemImage: "checkmark") }
        Button {
            Task { try? await store.updateTask(task.snoozedByOneDay()) }
        } label: { Label("Snooze", systemImage: "clock.arrow.circlepath") }
        Button {
            Task { await CalendarService.addHouseholdTask(task) }
        } label: { Label("Add to calendar", systemImage: "calendar.badge.plus") }
        Button(role: .destructive) {
            Task { try? await store.deleteTask(task) }
        } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private func mealMenu(_ meal: Meal) -> some View {
        Button { selection = .meal(meal) } label: {
            Label("Open", systemImage: "square.and.pencil")
        }
        Button(role: .destructive) {
            Task { try? await store.deleteMeal(meal) }
        } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private func petMenu(_ pet: Pet) -> some View {
        Button(role: .destructive) {
            Task { try? await store.deletePet(pet) }
        } label: { Label("Delete", systemImage: "trash") }
    }
}

#Preview {
    SearchView()
        .environment(SupabaseStore())
}
