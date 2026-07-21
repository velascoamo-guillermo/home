import SwiftUI

struct MealsListView: View {
    @Environment(SupabaseStore.self) private var store

    @State private var searchText = ""
    @State private var editingMeal: Meal?
    @State private var isCreating = false
    @State private var mealToDelete: Meal?

    private var catalog: [Meal] {
        let all = store.meals
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.localizedStandardContains(q) }
    }

    var body: some View {
        List {
            if catalog.isEmpty {
                ContentUnavailableView(
                    "Sin meals",
                    systemImage: "fork.knife",
                    description: Text("Crea meals para armar el menú semanal.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(catalog) { meal in
                Button { editingMeal = meal } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.title.isEmpty ? "Sin título" : meal.title)
                        if let cals = meal.nutrition.calories {
                            Text("\(cals) kcal").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .glassRow()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { mealToDelete = meal } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .glassListStyle()
        .searchable(text: $searchText, prompt: "Buscar meal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nueva meal", systemImage: "plus") { isCreating = true }
            }
        }
        .sheet(item: $editingMeal) { meal in
            MealFormSheet(existing: meal)
        }
        .sheet(isPresented: $isCreating) {
            MealFormSheet(existing: nil)
        }
        .confirmationDialog(
            "¿Eliminar \"\(mealToDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { mealToDelete != nil },
                set: { if !$0 { mealToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let meal = mealToDelete { Task { try? await store.deleteMeal(meal) } }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminará también del menú semanal.")
        }
    }
}

#Preview {
    NavigationStack { MealsListView() }
        .environment(SupabaseStore())
}
