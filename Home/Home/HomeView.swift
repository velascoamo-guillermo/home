import SwiftUI

struct HomeView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var editingTask: HouseholdTask? = nil
    @State private var selectedEvent: PetEvent? = nil
    @State private var outOfStock: OutOfStockInfo? = nil

    private struct OutOfStockInfo: Identifiable {
        let id = UUID()
        let product: StockProduct
        let needed: Int
    }

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
                                    switch item {
                                    case .task(let t):
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
                                    case .event(let e, _):
                                        Button(role: .destructive) {
                                            Task { try? await store.deleteEvent(e) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    default:
                                        EmptyView()
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
            .sheet(item: $selectedEvent) { event in
                if let pet = store.pets.first(where: { $0.id == event.petId }) {
                    EventDetailView(event: event, pet: pet)
                }
            }
            .alert("Out of stock",
                   isPresented: Binding(
                       get: { outOfStock != nil },
                       set: { if !$0 { outOfStock = nil } }
                   ),
                   presenting: outOfStock) { _ in
                Button("OK", role: .cancel) { }
            } message: { info in
                Text("Needs \(info.needed), only \(info.product.totalUnits) left. Restock \(info.product.name) — the task was marked done anyway.")
            }
        }
    }

    private func handleTap(_ item: HomeItem) {
        switch item {
        case .task(let t):     editingTask = t
        case .event(let e, _): selectedEvent = e
        default:               break
        }
    }

    private func markDone(_ task: HouseholdTask) {
        Task {
            let result = try? await store.completeTask(task)
            if case .outOfStock(let product)? = result {
                outOfStock = OutOfStockInfo(product: product, needed: task.quantityPerCompletion)
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
