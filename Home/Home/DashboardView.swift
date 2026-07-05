import SwiftUI

struct DashboardView: View {
    @Environment(SupabaseStore.self) private var store

    @State private var config = DashboardConfig.default
    @State private var showAdd = false
    @State private var showEdit = false
    @State private var editingTask: HouseholdTask? = nil

    private let configStore = DashboardConfigStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    DashboardHeaderView(
                        tasksDueToday: tasksDueToday,
                        itemsToBuy: itemsToBuy
                    )
                    .padding(.bottom, 6)

                    if config.cards.isEmpty {
                        ContentUnavailableView(
                            "No cards",
                            systemImage: "square.grid.2x2",
                            description: Text("Tap Edit to add dashboard cards.")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(config.cards) { card in
                            DashboardCardView(card: card) { task in
                                editingTask = task
                            }
                        }
                    }
                }
                .padding(16)
                .animation(.spring(duration: 0.35), value: config.cards)
                .animation(.spring(duration: 0.35), value: tasksDueToday)
                .animation(.spring(duration: 0.35), value: itemsToBuy)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit", systemImage: "slider.horizontal.3") { showEdit = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add task", systemImage: "plus") { showAdd = true }
                }
            }
            .sheet(isPresented: $showAdd) { HouseholdTaskSheet() }
            .sheet(item: $editingTask) { task in HouseholdTaskSheet(existing: task) }
            .sheet(isPresented: $showEdit) {
                DashboardEditView(config: $config) { configStore.save($0) }
            }
        }
        .onAppear { config = configStore.load() }
    }

    private var tasksDueToday: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return store.householdTasks
            .filter { Calendar.current.startOfDay(for: $0.nextDueDate) <= today }
            .count
    }

    private var itemsToBuy: Int {
        DashboardData.shoppingList(
            stock: store.stockProducts,
            limit: DashboardData.shoppingLimit
        ).total
    }
}

#Preview {
    DashboardView()
        .environment(SupabaseStore())
}
