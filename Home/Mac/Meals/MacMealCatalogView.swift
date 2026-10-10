#if os(macOS)
import SwiftUI

struct MacMealCatalogView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var editing: Meal?
    @State private var mealToDelete: Meal?

    private var catalog: [Meal] {
        store.meals.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List(catalog) { meal in
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
            .contextMenu {
                Button("Edit Meal…") { editing = meal }
                Button("Delete…", role: .destructive) { mealToDelete = meal }
            }
        }
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
