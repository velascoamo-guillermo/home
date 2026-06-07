import SwiftUI

struct MenuView: View {
    @Environment(SupabaseStore.self) private var store

    @State private var editTarget: EditTarget?
    @State private var isSuggesting = false
    @State private var errorMessage: String?
    @State private var dayToClear: Weekday?

    private struct EditTarget: Identifiable {
        let id = UUID()
        let day: Int
        let slot: MealSlot
        let entry: MealEntry?
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Weekday.allCases) { weekday in
                    Section {
                        ForEach(MealSlot.allCases, id: \.self) { slot in
                            let entry = store.mealEntry(day: weekday.rawValue, slot: slot)
                            Button {
                                editTarget = EditTarget(day: weekday.rawValue, slot: slot,
                                                        entry: entry)
                            } label: {
                                MealSlotRow(
                                    slot: slot,
                                    entry: entry,
                                    onCook: {
                                        if let entry { Task { await cook(entry) } }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(weekday.displayName)
                            Spacer()
                            if store.meals.contains(where: { $0.dayOfWeek == weekday.rawValue }) {
                                Button("Vaciar día", systemImage: "trash") {
                                    dayToClear = weekday
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .tint(.red)
                                .accessibilityLabel("Vaciar \(weekday.displayName)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Menu")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await suggestWeek() }
                    } label: {
                        Label("Sugerir semana", systemImage: "sparkles")
                    }
                    .disabled(isSuggesting || store.emptyMealSlots.isEmpty)
                }
            }
            .overlay {
                if isSuggesting {
                    ProgressView("Planificando la semana…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .sheet(item: $editTarget) { target in
                MealEditSheet(
                    dayOfWeek: target.day,
                    slot: target.slot,
                    entry: target.entry
                )
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
    MenuView()
        .environment(SupabaseStore())
}
