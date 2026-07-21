import SwiftUI

struct MealPickerSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let day: Int
    let slot: MealSlot

    @State private var searchText = ""
    @State private var isCreating = false
    @State private var editingMeal: Meal?

    private var current: MealEntry? { store.mealEntry(day: day, slot: slot) }

    private var catalog: [Meal] {
        let all = store.meals
            .filter { !$0.title.isEmpty }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.localizedStandardContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let current {
                    Section {
                        Button("Editar meal", systemImage: "square.and.pencil") {
                            editingMeal = current.meal
                        }
                        Button("Quitar del día", systemImage: "minus.circle", role: .destructive) {
                            Task {
                                try? await store.unassign(day: day, slot: slot)
                                dismiss()
                            }
                        }
                    }
                }
                Section("Meals") {
                    if catalog.isEmpty {
                        Text("No hay meals. Crea la primera.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(catalog) { meal in
                        Button {
                            Task {
                                try? await store.assign(mealId: meal.id, day: day, slot: slot)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.title)
                                    if let cals = meal.nutrition.calories {
                                        Text("\(cals) kcal")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if current?.meal.id == meal.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar meal")
            .navigationTitle("\(Weekday(rawValue: day)?.displayName ?? "") · \(slot.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Nueva meal", systemImage: "plus") { isCreating = true }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $isCreating) {
                MealFormSheet(existing: nil) { meal in
                    Task {
                        try? await store.assign(mealId: meal.id, day: day, slot: slot)
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingMeal) { meal in
                MealFormSheet(existing: meal)
            }
        }
    }
}
