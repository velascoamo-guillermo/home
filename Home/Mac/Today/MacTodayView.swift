#if os(macOS)
import AppKit
import Combine
import SwiftUI

struct MacTodayView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @Environment(CalendarFeed.self) private var feed
    @Environment(\.undoManager) private var undoManager

    @State private var today = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var selection: AgendaItem.ID?
    @State private var outOfStock: OutOfStockInfo?

    private let calendar = Calendar.current

    static func commands(for item: AgendaItem?) -> Set<MacFeatureCommand> {
        guard case .task(_, let occurrence)? = item, occurrence != .projected else { return [] }
        return [.markDone, .snoozeOneDay]
    }

    var body: some View {
        let input = agendaInput
        let day = AgendaBuilder.build(day: selectedDay, today: today, calendar: calendar, input: input)
        let selected = day.groups.flatMap(\.items).first { $0.id == selection }

        List(selection: $selection) {
            Section {
                AgendaHeaderView(
                    now: .now,
                    tasksDue: AgendaHeaderView.tasksDue(store.householdTasks, today: today, calendar: calendar),
                    itemsToBuy: store.shoppingList.count)
                WeekStripView(selectedDay: $selectedDay, today: today) { date in
                    AgendaBuilder.dotCount(day: date, today: today, calendar: calendar, input: input)
                }
                if feed.showsBanner {
                    CalendarAccessBanner(
                        state: feed.accessState,
                        onAllow: { Task { await feed.requestAccess() } },
                        onDismiss: { feed.dismissBanner() })
                }
            }
            .selectionDisabled()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if day.isEmpty {
                Text("Nothing planned")
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .selectionDisabled()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(day.groups) { group in
                    Section(group.section.title) {
                        ForEach(group.items) { item in
                            AgendaRow(item: item, onComplete: completion(for: item))
                                .tag(item.id)
                                .pastelRow(AgendaRow.fill(for: item))
                        }
                    }
                }
            }
        }
        .flatListStyle()
        .contextMenu(forSelectionType: AgendaItem.ID.self) { ids in
            if let item = day.groups.flatMap(\.items).first(where: { $0.id == ids.first }) {
                contextMenu(for: item)
            }
        } primaryAction: { ids in
            guard let item = day.groups.flatMap(\.items).first(where: { $0.id == ids.first }) else { return }
            open(item)
        }
        .onDeleteCommand {
            if case .task(let task, _)? = selected { delete(task) }
        }
        .background(ReturnKeyCatcher {
            guard let selected else { return false }
            open(selected)
            return true
        })
        .inspector(isPresented: $model.isInspectorPresented) {
            inspector(for: selected)
                .inspectorColumnWidth(min: 360, ideal: 400, max: 520)
        }
        .task(id: AgendaWeek.fetchInterval(containing: selectedDay, calendar: calendar)) {
            await feed.load(interval: AgendaWeek.fetchInterval(containing: selectedDay, calendar: calendar))
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshToday()
        }
        .onChange(of: selection, initial: true) { _, _ in
            model.availableCommands = Self.commands(for: selected)
        }
        .onChange(of: model.requestedCommand) { _, command in
            run(command, on: selected)
        }
        .outOfStockAlert($outOfStock)
    }

    private var agendaInput: AgendaInput {
        AgendaInput(tasks: store.householdTasks, appointments: store.appointments, petEvents: store.events,
                    pets: store.pets, menuEntries: store.menuEntries, meals: store.meals,
                    calendarEvents: feed.events)
    }

    @ViewBuilder
    private func contextMenu(for item: AgendaItem) -> some View {
        switch item {
        case .task(let task, let occurrence) where occurrence != .projected:
            TaskContextMenu(task: task, onCompleted: handle, onDelete: delete)
        case .appointment(let appointment, let pet):
            AppointmentContextMenu(appointment: appointment, petName: pet.name)
        case .petEvent(let event, let pet):
            EventContextMenu(event: event, petName: pet.name)
        case .calendarEvent:
            Button("Open in Calendar") { openCalendar() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func inspector(for item: AgendaItem?) -> some View {
        switch item {
        case .task(let task, _)?:
            HouseholdTaskSheet(existing: task).id(task.id)
        case .petEvent(let event, let pet)?:
            EventDetailView(event: event, pet: pet).id(event.id)
        case let item?:
            ContentUnavailableView(item.title, systemImage: "info.circle",
                                   description: Text(AgendaRow.accessibilityLabel(for: item) ?? item.title))
        case nil:
            ContentUnavailableView("No Selection", systemImage: "sidebar.trailing",
                                   description: Text("Select an item to see its details."))
        }
    }

    private func open(_ item: AgendaItem) {
        if case .calendarEvent = item {
            openCalendar()
        } else {
            model.isInspectorPresented = true
        }
    }

    private func openCalendar() {
        guard let calendarApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.open(calendarApp)
    }

    private func completion(for item: AgendaItem) -> (() -> Void)? {
        guard case .task(let task, let occurrence) = item, occurrence != .projected else { return nil }
        return { complete(task) }
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

    private func run(_ command: MacFeatureCommand?, on item: AgendaItem?) {
        guard let command else { return }
        model.requestedCommand = nil
        guard case .task(let task, _)? = item else { return }
        switch command {
        case .markDone:     complete(task)
        case .snoozeOneDay: Task { try? await store.updateTask(task.snoozed(byDays: 1)) }
        default:            break
        }
    }

    private func refreshToday() {
        let newToday = calendar.startOfDay(for: .now)
        guard newToday != today else { return }
        if selectedDay == today { selectedDay = newToday }
        today = newToday
    }
}

// `contextMenu(forSelectionType:primaryAction:)` only reaches its `primaryAction`
// closure on a real double-click; pressing Return on a selected row never calls it
// on this SDK because an accessibility-driven row selection (as in UI tests, and
// seemingly also real clicks in this List) never promotes the row to first
// responder, so no keyDown ever reaches a SwiftUI `.onKeyPress`. A local key-down
// monitor intercepts Return at the window level instead, which only requires the
// window to be key — already true once a row is selected.
private struct ReturnKeyCatcher: NSViewRepresentable {
    let onReturn: () -> Bool

    final class Coordinator {
        var onReturn: () -> Bool
        var monitor: Any?

        init(onReturn: @escaping () -> Bool) { self.onReturn = onReturn }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onReturn: onReturn) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [coordinator = context.coordinator] event in
            guard event.keyCode == 36, view.window?.isKeyWindow == true else { return event }
            return coordinator.onReturn() ? nil : event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onReturn = onReturn
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }
}
#endif
