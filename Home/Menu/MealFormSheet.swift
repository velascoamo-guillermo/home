import SwiftUI

struct MealFormSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Meal?
    private let onSaved: ((Meal) -> Void)?

    @State private var title: String
    @State private var links: [MealEntry.Link]
    @State private var servingsText: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var errorMessage: String?

    init(existing: Meal?, onSaved: ((Meal) -> Void)? = nil) {
        self.existing = existing
        self.onSaved = onSaved
        let nutrition = existing?.nutrition ?? Nutrition()
        _title = State(initialValue: existing?.title ?? "")
        _links = State(initialValue: [])
        _servingsText = State(initialValue: existing?.servings.map(String.init) ?? "")
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
            .navigationTitle(existing == nil ? "Nueva meal" : "Editar meal")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task { loadLinks() }
            .alert("No se pudo guardar", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func loadLinks() {
        guard let existing else { return }
        links = store.mealProducts
            .filter { $0.mealId == existing.id }
            .compactMap { mp in
                guard let product = store.stockProducts.first(where: { $0.id == mp.productId })
                else { return nil }
                return MealEntry.Link(product: product)
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
        var meal = existing ?? Meal()
        meal.title = title
        meal.servings = Int(servingsText)
        meal.nutrition = Nutrition(
            calories: Int(caloriesText),
            proteinG: Int(proteinText),
            carbsG:   Int(carbsText),
            fatG:     Int(fatText)
        )
        do {
            if existing != nil {
                try await store.updateMeal(meal)
            } else {
                try await store.addMeal(meal)
            }
            try await store.setMealProducts(for: meal, links: links)
            onSaved?(meal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
