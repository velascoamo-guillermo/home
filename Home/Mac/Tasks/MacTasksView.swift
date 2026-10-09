#if os(macOS)
import SwiftUI

struct MacTasksView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var selection: UUID?
    @State private var selectedEvent: PetEvent?
    @State private var outOfStock: OutOfStockInfo?

    /// Looked up by id on every render so a task deleted elsewhere drops out of the inspector.
    private var selectedTask: HouseholdTask? {
        selection.flatMap { id in store.householdTasks.first { $0.id == id } }
    }

    var body: some View {
        let groups = TaskSectionGrouping.groups(store.householdTasks, customSections: store.customSections)
        let petItems = store.homeTimeline.filter { if case .task = $0 { false } else { true } }

        Group {
            if groups.isEmpty && petItems.isEmpty {
                ContentUnavailableView("Nothing Scheduled", systemImage: "calendar.badge.clock",
                                       description: Text("Add a household task with File ▸ New Task."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gradientCanvas()
            } else {
                List(selection: $selection) {
                    ForEach(groups) { group in
                        Section(group.title) {
                            ForEach(group.tasks) { task in
                                HomeItemRow(item: .task(task), onComplete: { complete(task) })
                                    .tag(task.id)
                                    .pastelRow(Palette.tasks)
                            }
                        }
                    }
                    if !petItems.isEmpty {
                        Section("Pet Appointments and Events") {
                            ForEach(petItems) { item in
                                HomeItemRow(item: item)
                                    .selectionDisabled()
                                    .pastelRow(Palette.pets)
                                    .contextMenu { petMenu(item) }
                            }
                        }
                    }
                }
                .flatListStyle()
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let task = store.householdTasks.first(where: { $0.id == ids.first }) {
                        TaskContextMenu(task: task, onCompleted: handle, onDelete: delete)
                    }
                } primaryAction: { ids in
                    if store.householdTasks.contains(where: { $0.id == ids.first }) {
                        model.isInspectorPresented = true
                    }
                }
                .onDeleteCommand {
                    if let task = selectedTask { delete(task) }
                }
                .background(ListFocusView(selection: selection))
            }
        }
        .inspector(isPresented: $model.isInspectorPresented) {
            Group {
                if let task = selectedTask {
                    HouseholdTaskSheet(existing: task).id(task.id)
                } else {
                    ContentUnavailableView("No Selection", systemImage: "sidebar.trailing",
                                           description: Text("Select a task to edit it."))
                }
            }
            .inspectorColumnWidth(min: 360, ideal: 400, max: 520)
        }
        .sheet(item: $selectedEvent) { event in
            if let pet = store.pets.first(where: { $0.id == event.petId }) {
                EventDetailView(event: event, pet: pet)
            }
        }
        .onChange(of: selectedTask?.id, initial: true) { _, id in
            model.availableCommands = id == nil ? [] : [.markDone, .snoozeOneDay]
        }
        .onChange(of: model.requestedCommand) { _, command in run(command) }
        .outOfStockAlert($outOfStock)
    }

    @ViewBuilder
    private func petMenu(_ item: HomeItem) -> some View {
        switch item {
        case .appointment(let appointment, let pet):
            AppointmentContextMenu(appointment: appointment, petName: pet.name)
        case .event(let event, let pet):
            Button("Open Event…") { selectedEvent = event }
            EventContextMenu(event: event, petName: pet.name)
        case .task:
            EmptyView()
        }
    }

    private func complete(_ task: HouseholdTask) {
        Task {
            if let result = try? await store.completeTask(task) { handle(result) }
        }
    }

    private func handle(_ result: SupabaseStore.CompletionResult) {
        if case .outOfStock(let product) = result { outOfStock = OutOfStockInfo(product: product) }
    }

    private func delete(_ task: HouseholdTask) {
        Task { try? await store.deleteTask(task, undoManager: undoManager) }
    }

    private func run(_ command: MacFeatureCommand?) {
        guard let command else { return }
        model.requestedCommand = nil
        guard let task = selectedTask else { return }
        switch command {
        case .markDone:     complete(task)
        case .snoozeOneDay: Task { try? await store.updateTask(task.snoozed(byDays: 1)) }
        default:            break
        }
    }
}
#endif
