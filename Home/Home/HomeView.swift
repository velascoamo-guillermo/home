import SwiftUI

struct HomeView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var editingTask: HouseholdTask? = nil
    @State private var outOfStockProduct: StockProduct? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.homeTimeline.isEmpty {
                    ContentUnavailableView(
                        "Nothing scheduled",
                        systemImage: "calendar.badge.clock",
                        description: Text("Add a household task or schedule a pet appointment.")
                    )
                } else {
                    List {
                        ForEach(store.homeTimeline) { item in
                            HomeItemRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { handleTap(item) }
                                .swipeActions(edge: .leading) {
                                    if case .task(let t) = item {
                                        Button {
                                            markDone(t)
                                        } label: {
                                            Label("Done", systemImage: "checkmark")
                                        }
                                        .tint(.green)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    if case .task(let t) = item {
                                        Button(role: .destructive) {
                                            Task { try? await store.deleteTask(t) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }

                                        Button {
                                            snooze(t)
                                        } label: {
                                            Label("Snooze", systemImage: "clock.arrow.circlepath")
                                        }
                                        .tint(.orange)

                                        Button {
                                            Task { await CalendarService.addHouseholdTask(t) }
                                        } label: {
                                            Label("Calendar", systemImage: "calendar.badge.plus")
                                        }
                                        .tint(.blue)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add task", systemImage: "plus") { showAdd = true }
                }
            }
            .sheet(isPresented: $showAdd) {
                HouseholdTaskSheet()
            }
            .sheet(item: $editingTask) { task in
                HouseholdTaskSheet(existing: task)
            }
            .alert("Out of stock",
                   isPresented: Binding(
                       get: { outOfStockProduct != nil },
                       set: { if !$0 { outOfStockProduct = nil } }
                   ),
                   presenting: outOfStockProduct) { _ in
                Button("OK", role: .cancel) { }
            } message: { product in
                Text("Restock \(product.name) — the task was marked done anyway.")
            }
        }
    }

    private func handleTap(_ item: HomeItem) {
        if case .task(let t) = item { editingTask = t }
    }

    private func markDone(_ task: HouseholdTask) {
        Task {
            let result = try? await store.completeTask(task)
            if case .outOfStock(let product)? = result {
                outOfStockProduct = product
            }
        }
    }

    private func snooze(_ task: HouseholdTask) {
        var updated = task
        updated.nextDueDate = Calendar.current.date(byAdding: .day, value: 1, to: task.nextDueDate) ?? task.nextDueDate
        Task { try? await store.updateTask(updated) }
    }
}

#Preview {
    HomeView()
        .environment(SupabaseStore())
}
