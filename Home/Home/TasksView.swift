import SwiftUI

struct TasksView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var editingTask: HouseholdTask? = nil
    @State private var selectedEvent: PetEvent? = nil
    @State private var outOfStock: OutOfStockInfo? = nil

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
                        HomeItemRow(item: item, onComplete: completeAction(for: item))
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
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if case .task(let t) = item {
                                    Button { complete(t) } label: {
                                        Label("Done", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if case .task(let t) = item {
                                    Button(role: .destructive) {
                                        Task { try? await store.deleteTask(t) }
                                    } label: { Label("Delete", systemImage: "trash") }
                                    Button {
                                        Task { try? await store.updateTask(t.snoozedByOneDay()) }
                                    } label: { Label("Snooze 1d", systemImage: "clock.arrow.circlepath") }
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
        .outOfStockAlert($outOfStock)
    }

    private func handleTap(_ item: HomeItem) {
        switch item {
        case .task(let t):     editingTask = t
        case .event(let e, _): selectedEvent = e
        default:               break
        }
    }

    private func complete(_ t: HouseholdTask) {
        Task {
            if let result = try? await store.completeTask(t),
               case .outOfStock(let product) = result {
                outOfStock = OutOfStockInfo(product: product, needed: t.quantityPerCompletion)
            }
        }
    }

    private func completeAction(for item: HomeItem) -> (() -> Void)? {
        guard case .task(let t) = item else { return nil }
        return { complete(t) }
    }

}

#Preview {
    NavigationStack {
        TasksView()
    }
    .environment(SupabaseStore())
}
