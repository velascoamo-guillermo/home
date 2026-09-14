import Combine
import SwiftUI

struct AgendaView: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(CalendarFeed.self) private var feed
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var today = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var editingTask: HouseholdTask? = nil
    @State private var outOfStock: OutOfStockInfo? = nil

    private let calendar = Calendar.current

    var body: some View {
        let input = agendaInput
        let day = AgendaBuilder.build(day: selectedDay, today: today, calendar: calendar, input: input)

        NavigationStack {
            List {
                Section {
                    AgendaHeaderView(
                        now: .now,
                        tasksDue: AgendaHeaderView.tasksDue(store.householdTasks, today: today, calendar: calendar),
                        itemsToBuy: store.shoppingList.count
                    )
                    WeekStripView(selectedDay: $selectedDay, today: today) { date in
                        AgendaBuilder.dotCount(day: date, today: today, calendar: calendar, input: input)
                    }
                    if feed.showsBanner {
                        CalendarAccessBanner(
                            state: feed.accessState,
                            onAllow: { Task { await feed.requestAccess() } },
                            onDismiss: { feed.dismissBanner() }
                        )
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                if day.isEmpty {
                    Text("Nothing planned ✨")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(day.groups) { group in
                        Section(group.section.title) {
                            ForEach(group.items) { item in
                                row(item)
                            }
                        }
                    }
                }
            }
            .flatListStyle()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.spring(duration: 0.35), value: day)
            .sheet(item: $editingTask) { task in HouseholdTaskSheet(existing: task) }
            .outOfStockAlert($outOfStock)
        }
        .task(id: AgendaWeek.fetchInterval(containing: selectedDay, calendar: calendar)) {
            await feed.load(interval: AgendaWeek.fetchInterval(containing: selectedDay, calendar: calendar))
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshToday()
            Task { await feed.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshToday()
        }
    }

    private var agendaInput: AgendaInput {
        AgendaInput(
            tasks: store.householdTasks,
            appointments: store.appointments,
            petEvents: store.events,
            pets: store.pets,
            menuEntries: store.menuEntries,
            meals: store.meals,
            calendarEvents: feed.events
        )
    }

    @ViewBuilder
    private func row(_ item: AgendaItem) -> some View {
        let fill = AgendaRow.fill(for: item)
        switch item {
        case .task(_, .projected):
            AgendaRow(item: item)
                .pastelRow(fill)
        case .task(let task, _):
            AgendaRow(item: item, onComplete: { complete(task) })
                .contentShape(Rectangle())
                .onTapGesture { editingTask = task }
                .contextMenu { TaskContextMenu(task: task) { handle($0, for: task) } }
                .pastelRow(fill)
        case .appointment(let appt, let pet):
            AgendaRow(item: item)
                .contextMenu { AppointmentContextMenu(appointment: appt, petName: pet.name) }
                .pastelRow(fill)
        case .petEvent(let event, let pet):
            AgendaRow(item: item)
                .contextMenu { EventContextMenu(event: event, petName: pet.name) }
                .pastelRow(fill)
        case .meal:
            AgendaRow(item: item)
                .pastelRow(fill)
        case .calendarEvent(let event, _):
            Button { openInCalendar(event) } label: { AgendaRow(item: item) }
                .buttonStyle(.plain)
                .pastelRow(fill)
        }
    }

    private func complete(_ task: HouseholdTask) {
        Task {
            if let result = try? await store.completeTask(task) {
                handle(result, for: task)
            }
        }
    }

    private func handle(_ result: SupabaseStore.CompletionResult, for task: HouseholdTask) {
        if case .outOfStock(let product) = result {
            outOfStock = OutOfStockInfo(product: product, needed: task.quantityPerCompletion)
        }
    }

    private func openInCalendar(_ event: CalendarEventSnapshot) {
        guard let url = URL(string: "calshow:\(Int(event.start.timeIntervalSinceReferenceDate))") else { return }
        openURL(url)
    }

    private func refreshToday() {
        let newToday = calendar.startOfDay(for: .now)
        guard newToday != today else { return }
        if selectedDay == today { selectedDay = newToday }
        today = newToday
    }
}

#Preview {
    AgendaView()
        .environment(SupabaseStore())
        .environment(CalendarFeed(source: FakeCalendarSource.uiTestFixture()))
}
