import SwiftUI

struct TasksView: View {
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
                            .glassRow()
                            .contextMenu {
                                switch item {
                                case .task(let t):
                                    TaskContextMenu(task: t) { result in
                                        if case .outOfStock(let product) = result {
                                            outOfStock = OutOfStockInfo(
                                                product: product,
                                                needed: t.quantityPerCompletion
                                            )
                                        }
                                    }
                                case .event(let e, let pet):
                                    EventContextMenu(event: e, petName: pet.name)
                                case .appointment(let a, let pet):
                                    AppointmentContextMenu(appointment: a, petName: pet.name)
                                }
                            }
                    }
                }
                .glassListStyle()
            }
        }
        .navigationTitle("Tasks")
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

    private func handleTap(_ item: HomeItem) {
        switch item {
        case .task(let t):     editingTask = t
        case .event(let e, _): selectedEvent = e
        default:               break
        }
    }

}

#Preview {
    NavigationStack {
        TasksView()
    }
    .environment(SupabaseStore())
}
