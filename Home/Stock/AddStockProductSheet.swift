import SwiftUI

struct AddStockProductSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existing: StockProduct?

    @State private var name = ""
    @State private var level: StockLevel = .full
    @State private var supermarket: Supermarket?
    @State private var category: ProductCategory?

    private var isEditing: Bool { existing != nil }

    init(existing: StockProduct? = nil) {
        self.existing = existing
        if let p = existing {
            _name        = State(initialValue: p.name)
            _level       = State(initialValue: p.level)
            _supermarket = State(initialValue: p.supermarket)
            _category    = State(initialValue: p.category)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name", text: $name)
                    Picker("Level", selection: $level) {
                        ForEach(StockLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Supermarket", selection: $supermarket) {
                        Text("None").tag(Supermarket?.none)
                        ForEach(Supermarket.allCases) { market in
                            Text(market.displayName).tag(Supermarket?.some(market))
                        }
                    }
                }
                Section {
                    ChipGroup(
                        items: ProductCategory.allCases,
                        selection: $category,
                        fill: Palette.stock,
                        title: \.displayName,
                        systemImage: \.icon
                    )
                } header: {
                    Text("Category")
                } footer: {
                    Text("Tap the selected category again to clear.")
                }
            }
            .scrollContentBackground(.hidden)
            .gradientCanvas()
            .navigationTitle(isEditing ? "Edit Product" : "New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        var product = existing ?? StockProduct(name: "", level: level)
        product.name        = name.trimmingCharacters(in: .whitespaces)
        product.level       = level
        product.supermarket = supermarket
        product.category    = category

        Task {
            if isEditing {
                try? await store.updateProduct(product)
            } else {
                try? await store.addProduct(product)
            }
            dismiss()
        }
    }
}
