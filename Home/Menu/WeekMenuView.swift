import SwiftUI

struct WeekMenuView: View {
    @Environment(SupabaseStore.self) private var store

    @State private var selectedDay = Weekday(date: .now, calendar: .current)
    @State private var editTarget: EditTarget?
    @State private var isSuggesting = false
    @State private var errorMessage: String?
    @State private var dayToClear: Weekday?

    private struct EditTarget: Identifiable {
        let id = UUID()
        let day: Int
        let slot: MealSlot
    }

    var body: some View {
        let summary = weekSummary
        let today = Weekday(date: .now, calendar: .current)

        List {
            Section {
                MenuHeaderView(
                    today: today,
                    summary: summary,
                    onPlannedTap: { selectIfFound(summary.firstDayWithEmptySlot(from: today)) },
                    onShortTap: { selectIfFound(summary.firstShortDay(from: today)) }
                )
                MenuDayStripView(selectedDay: $selectedDay, today: today) { summary.plannedSlots(on: $0) }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

            Section {
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    slotRow(slot, entry: summary.entry(day: selectedDay, slot: slot))
                        .id("\(selectedDay.rawValue)-\(slot.rawValue)")
                }
            } header: {
                dayHeader(isToday: selectedDay == today, hasEntries: !summary.plannedSlots(on: selectedDay).isEmpty)
            }
        }
        .flatListStyle()
        .animation(.spring(duration: 0.35), value: selectedDay)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await suggestWeek() }
                } label: {
                    Label("Sugerir semana", systemImage: "sparkles")
                }
                .disabled(isSuggesting || store.emptyMealSlots.isEmpty
                          || store.meals.allSatisfy { $0.title.isEmpty })
            }
        }
        .overlay {
            if isSuggesting {
                ProgressView("Planificando la semana…")
                    .padding()
                    .background(Palette.surface, in: .rect(cornerRadius: 12))
            }
        }
        .sheet(item: $editTarget) { target in
            MealPickerSheet(day: target.day, slot: target.slot)
        }
        .confirmationDialog(
            "¿Vaciar \(dayToClear?.displayName ?? "")?",
            isPresented: Binding(
                get: { dayToClear != nil },
                set: { if !$0 { dayToClear = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Vaciar día", role: .destructive) {
                if let day = dayToClear { Task { await clearDay(day.rawValue) } }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("No se pudo sugerir", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var weekSummary: MenuWeekSummary {
        MenuWeekSummary(entries: Weekday.allCases.flatMap { day in
            MealSlot.allCases.compactMap { store.mealEntry(day: day.rawValue, slot: $0) }
        })
    }

    @ViewBuilder
    private func slotRow(_ slot: MealSlot, entry: MealEntry?) -> some View {
        let day = selectedDay.rawValue
        let card = MealSlotCard(
            slot: slot,
            entry: entry,
            onCook: { if let entry { Task { await cook(entry) } } },
            onAddMissing: { if let entry { Task { await store.markMissingNeeded(for: entry) } } }
        )
        let open = { editTarget = EditTarget(day: day, slot: slot) }

        Button(action: open) {
            card.contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mealSlot-\(slot.rawValue)")
        .pastelRow(entry == nil ? Palette.surface : Palette.meals)
    }

    private func dayHeader(isToday: Bool, hasEntries: Bool) -> some View {
        HStack {
            Text(isToday ? "\(selectedDay.displayName) · Hoy" : selectedDay.displayName)
            Spacer()
            if hasEntries {
                Button("Vaciar día", systemImage: "trash") {
                    dayToClear = selectedDay
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .tint(.red)
                .accessibilityLabel("Vaciar \(selectedDay.displayName)")
            }
        }
    }

    private func selectIfFound(_ day: Weekday?) {
        guard let day else { return }
        withAnimation(.spring(duration: 0.3)) { selectedDay = day }
    }

    private func suggestWeek() async {
        isSuggesting = true
        defer { isSuggesting = false }
        do {
            try await store.suggestWeek()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    private func clearDay(_ day: Int) async {
        do {
            try await store.clearDay(day)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cook(_ entry: MealEntry) async {
        do {
            try await store.cookMeal(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { WeekMenuView() }
        .environment(SupabaseStore())
}
