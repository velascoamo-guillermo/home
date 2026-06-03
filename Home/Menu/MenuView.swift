import SwiftUI

struct MenuView: View {
    @Environment(SupabaseStore.self) private var store

    @State private var editTarget: EditTarget?
    @State private var loadingSlot: SlotKey?
    @State private var errorMessage: String?

    private struct SlotKey: Hashable { let day: Int; let slot: MealSlot }

    private struct EditTarget: Identifiable {
        let id = UUID()
        let day: Int
        let slot: MealSlot
        let entry: MealEntry?
        let suggestion: MealSuggestion?
        let suggestedLinks: [MealEntry.Link]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Weekday.allCases) { weekday in
                    Section(weekday.displayName) {
                        ForEach(MealSlot.allCases, id: \.self) { slot in
                            let entry = store.mealEntry(day: weekday.rawValue, slot: slot)
                            Button {
                                editTarget = EditTarget(day: weekday.rawValue, slot: slot,
                                                        entry: entry, suggestion: nil,
                                                        suggestedLinks: [])
                            } label: {
                                MealSlotRow(
                                    slot: slot,
                                    entry: entry,
                                    onSuggest: {
                                        Task { await suggest(day: weekday.rawValue, slot: slot) }
                                    },
                                    onCook: {
                                        if let entry { Task { await cook(entry) } }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Menu")
            .overlay {
                if loadingSlot != nil {
                    ProgressView("Pensando…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .sheet(item: $editTarget) { target in
                MealEditSheet(
                    dayOfWeek: target.day,
                    slot: target.slot,
                    entry: target.entry,
                    suggestion: target.suggestion,
                    suggestedLinks: target.suggestedLinks
                )
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

    private func suggest(day: Int, slot: MealSlot) async {
        loadingSlot = SlotKey(day: day, slot: slot)
        defer { loadingSlot = nil }
        do {
            let suggestion = try await store.suggestMeal(day: day, slot: slot)
            let links = suggestion.resolveLinks(against: store.stockProducts)
            editTarget = EditTarget(day: day, slot: slot, entry: nil,
                                    suggestion: suggestion, suggestedLinks: links)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
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
