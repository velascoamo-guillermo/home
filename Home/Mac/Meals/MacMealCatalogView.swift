#if os(macOS)
import SwiftUI

struct MacMealCatalogView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var editing: Meal?
    @State private var mealToDelete: Meal?
    @State private var selection: Meal.ID?

    private var catalog: [Meal] {
        store.meals.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Looked up by id, like the other Mac lists, so a meal edited or removed elsewhere drops
    /// out (or updates) without a stale selection.
    static func meal(for selection: Meal.ID?, in catalog: [Meal]) -> Meal? {
        selection.flatMap { id in catalog.first { $0.id == id } }
    }

    private var selectedMeal: Meal? { Self.meal(for: selection, in: catalog) }

    var body: some View {
        List(selection: $selection) {
            ForEach(catalog) { meal in
                Button { editing = meal } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.title.isEmpty ? "Sin título" : meal.title)
                            .foregroundStyle(Palette.ink)
                        if let calories = meal.nutrition.calories {
                            Text("\(calories) kcal")
                                .font(.caption)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .tag(meal.id)
            }
        }
        .contextMenu(forSelectionType: Meal.ID.self) { ids in
            if let meal = Self.meal(for: ids.first, in: catalog) {
                Button("Edit Meal…") { editing = meal }
                Button("Delete…", role: .destructive) { mealToDelete = meal }
            }
        } primaryAction: { ids in
            if let meal = Self.meal(for: ids.first, in: catalog) { editing = meal }
        }
        .onDeleteCommand {
            if let meal = selectedMeal { mealToDelete = meal }
        }
        .background(ListFocusView(selection: selection))
        .navigationTitle("Catalog")
        .sheet(item: $editing) { meal in MealFormSheet(existing: meal) }
        .confirmationDialog(
            "Delete \(mealToDelete?.title ?? "")?",
            isPresented: Binding(get: { mealToDelete != nil }, set: { if !$0 { mealToDelete = nil } }),
            titleVisibility: .visible,
            presenting: mealToDelete
        ) { meal in
            Button("Delete Meal", role: .destructive) { Task { try? await store.deleteMeal(meal) } }
        } message: { _ in
            Text("It is also removed from every day of the week.")
        }
    }
}
#endif
