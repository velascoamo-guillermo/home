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
                if config.cards.isEmpty {
                    ContentUnavailableView(
                        "No cards",
                        systemImage: "square.grid.2x2",
                        description: Text("Tap Edit to add dashboard cards.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(config.cards) { card in
                            DashboardCardView(card: card) { task in
                                editingTask = task
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Home")
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
}

#Preview {
    DashboardView()
        .environment(SupabaseStore())
}
