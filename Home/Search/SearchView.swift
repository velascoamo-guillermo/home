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
                                }
                            }
                        }
                        if !results.pets.isEmpty {
                            Section("Pets") {
                                ForEach(results.pets) { pet in
                                    NavigationLink(value: pet) {
                                        PetRow(pet: pet)
                                    }
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
}

#Preview {
    SearchView()
        .environment(SupabaseStore())
}
