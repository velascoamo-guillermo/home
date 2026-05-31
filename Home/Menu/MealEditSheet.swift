import SwiftUI

struct MealEditSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let dayOfWeek: Int
    let slot: MealSlot

    @State private var title: String
    @State private var links: [MealEntry.Link]
    @State private var servingsText: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    private let existingMeal: Meal?

    init(dayOfWeek: Int, slot: MealSlot, entry: MealEntry?,
         suggestion: MealSuggestion? = nil, suggestedLinks: [MealEntry.Link] = []) {
        self.dayOfWeek = dayOfWeek
        self.slot = slot
        self.existingMeal = entry?.meal

        let nutrition = suggestion?.nutrition ?? entry?.meal.nutrition ?? Nutrition()
        _title = State(initialValue: suggestion?.title ?? entry?.meal.title ?? "")
        _links = State(initialValue: suggestion != nil ? suggestedLinks : (entry?.links ?? []))
        _servingsText = State(initialValue: (suggestion?.servings ?? entry?.meal.servings).map(String.init) ?? "")
        _caloriesText = State(initialValue: nutrition.calories.map(String.init) ?? "")
        _proteinText  = State(initialValue: nutrition.proteinG.map(String.init) ?? "")
        _carbsText    = State(initialValue: nutrition.carbsG.map(String.init) ?? "")
        _fatText      = State(initialValue: nutrition.fatG.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Comida") {
                    TextField("Título del plato", text: $title)
                }
                Section("Productos de stock") {
                    MealProductPicker(links: $links)
                }
                Section("Nutrición (opcional)") {
                    numberField("Raciones", $servingsText)
                    numberField("Calorías (kcal)", $caloriesText)
                    numberField("Proteína (g)", $proteinText)
                    numberField("Carbohidratos (g)", $carbsText)
                    numberField("Grasa (g)", $fatText)
                }
            }
            .navigationTitle(slot.displayName)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                }
                ToolbarItem(placement: .cancelAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func numberField(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: binding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() async {
        let nutrition = Nutrition(
            calories: Int(caloriesText),
            proteinG: Int(proteinText),
            carbsG:   Int(carbsText),
            fatG:     Int(fatText)
        )
        var meal = existingMeal ?? Meal(dayOfWeek: dayOfWeek, slot: slot)
        meal.title = title
        meal.servings = Int(servingsText)
        meal.nutrition = nutrition

        do {
            if existingMeal != nil {
                try await store.updateMeal(meal)
            } else {
                try await store.addMeal(meal)
            }
            try await store.setMealProducts(for: meal, links: links)
            dismiss()
        } catch {
            dismiss()
        }
    }
}
