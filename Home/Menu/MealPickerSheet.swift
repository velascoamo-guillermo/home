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

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private var filteredCatalog: [Meal] {
        let all = store.meals
            .filter { !$0.title.isEmpty }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return all.filter { $0.title.localizedStandardContains(searchQuery) }
    }

    private var split: (recents: [Meal], rest: [Meal]) {
        MealCatalogOrder.split(meals: store.meals, entries: store.menuEntries)
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
                if !searchQuery.isEmpty {
                    Section("Meals") {
                        if filteredCatalog.isEmpty {
                            Text("No hay meals. Crea la primera.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(filteredCatalog) { meal in
                            mealRow(meal)
                        }
                    }
                } else {
                    if !split.recents.isEmpty {
                        Section("Recientes") {
                            ForEach(split.recents) { meal in
                                mealRow(meal)
                            }
                        }
                    }
                    Section("Meals") {
                        if split.recents.isEmpty && split.rest.isEmpty {
                            Text("No hay meals. Crea la primera.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(split.rest) { meal in
                            mealRow(meal)
                        }
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

    private func mealRow(_ meal: Meal) -> some View {
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

enum MealCatalogOrder {
    nonisolated static func split(meals: [Meal], entries: [MenuEntry],
                                  recentsLimit: Int = 5) -> (recents: [Meal], rest: [Meal]) {
        let lastUse = Dictionary(grouping: entries, by: \.mealId)
            .mapValues { $0.map(\.updatedAt).max() ?? .distantPast }
        let sortedAll = meals
            .filter { !$0.title.isEmpty }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let recents = sortedAll
            .compactMap { meal in lastUse[meal.id].map { (meal, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(recentsLimit)
            .map(\.0)
        let recentIds = Set(recents.map(\.id))
        return (Array(recents), sortedAll.filter { !recentIds.contains($0.id) })
    }
}
