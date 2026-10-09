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
        .background(AgendaListFocusView(selection: selection))
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

// Clicking (or AX-selecting, as in UI tests) an agenda row changes the SwiftUI
// `selection` binding but never promotes the List's backing NSOutlineView to
// `NSWindow.firstResponder` on this SDK — confirmed by instrumenting
// `window.firstResponder` directly: after a row click it stays the window itself,
// so `.onDeleteCommand`, `.onKeyPress`, and `contextMenu(forSelectionType:)`'s own
// Return handling (which only reaches `primaryAction` once the outline view is
// first responder) never fire. Promoting the outline view to first responder
// fixes all three natively, with no event interception — but only the ONE time
// the selection actually changes (`shouldApplyFocus`/`Coordinator.lastAppliedSelection`):
// `updateNSView` otherwise runs on every unrelated body re-render (a sync pull, a
// calendar feed load, an inspector field edit), and re-grabbing focus on each of
// those would yank it away from non-text inspector controls (DatePicker, Stepper,
// Picker, the Save button) and the sidebar whenever nothing else currently holds
// it (`applyFocus`'s guard: only promote when the current first responder is the
// window itself, nil, or already the outline view).
//
// `nearestOutlineView` is scoped to the outline view owned by the pane this view
// lives in: it climbs `nsView`'s own superview chain (this view sits as a
// `.background` of the Today `List`, inside the detail pane) rather than
// searching from `window.contentView`, which would also contain the sidebar's
// own `NSOutlineView` and could match that one instead (see
// `AgendaListFocusViewTests.scopesToTheOwningPane`).
struct AgendaListFocusView: NSViewRepresentable {
    let selection: AgendaItem.ID?

    final class Coordinator {
        var lastAppliedSelection: AgendaItem.ID?

        /// An attempt that couldn't find its window or list (still mid-layout) is
        /// forgotten so the next update retries it; one that found them but declined
        /// because another control holds focus stays recorded — that refusal is correct.
        func focusAttempt(for selection: AgendaItem.ID, resolved: Bool) {
            guard !resolved, lastAppliedSelection == selection else { return }
            lastAppliedSelection = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        guard Self.shouldApplyFocus(selection: selection, coordinator: coordinator),
              let selection else { return }
        coordinator.lastAppliedSelection = selection
        // The outline view isn't always findable yet in this same SwiftUI commit
        // (it can still be mid-layout right after a selection-driven re-render),
        // so promotion is deferred one main-actor turn rather than attempted here.
        // This hop happens once per selection change, never once per render.
        Task { @MainActor in
            coordinator.focusAttempt(for: selection, resolved: Self.applyFocus(from: nsView))
        }
    }

    static func shouldApplyFocus(selection: AgendaItem.ID?, coordinator: Coordinator) -> Bool {
        guard let selection else {
            coordinator.lastAppliedSelection = nil
            return false
        }
        return coordinator.lastAppliedSelection != selection
    }

    /// Returns false only when there is no window or list to focus yet.
    static func applyFocus(from view: NSView) -> Bool {
        guard let window = view.window, let outlineView = nearestOutlineView(ascendingFrom: view) else { return false }
        let responder = window.firstResponder
        guard responder == nil || responder === window || responder === outlineView else { return true }
        window.makeFirstResponder(outlineView)
        return true
    }

    static func nearestOutlineView(ascendingFrom view: NSView) -> NSOutlineView? {
        var ancestor = view.superview
        while let current = ancestor {
            if let found = outlineView(in: current) { return found }
            ancestor = current.superview
        }
        return nil
    }

    private static func outlineView(in view: NSView) -> NSOutlineView? {
        if let outlineView = view as? NSOutlineView { return outlineView }
        for subview in view.subviews {
            if let found = outlineView(in: subview) { return found }
        }
        return nil
    }
}
#endif
