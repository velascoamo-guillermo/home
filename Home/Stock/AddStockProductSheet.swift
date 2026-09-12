import SwiftUI

struct AddStockProductSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existing: StockProduct?

    @State private var name = ""
    @State private var unitsPerPackage = 1
    @State private var packages = 1
    @State private var looseUnits = 0
    @State private var supermarket: Supermarket?
    @State private var category: ProductCategory?

    private var isEditing: Bool { existing != nil }

    init(existing: StockProduct? = nil) {
        self.existing = existing
        if let p = existing {
            _name            = State(initialValue: p.name)
            _unitsPerPackage = State(initialValue: p.unitsPerPackage)
            _packages        = State(initialValue: p.packages)
            _looseUnits      = State(initialValue: p.looseUnits)
            _supermarket     = State(initialValue: p.supermarket)
            _category        = State(initialValue: p.category)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name", text: $name)
                    Picker("Supermarket", selection: $supermarket) {
                        Text("None").tag(Supermarket?.none)
                        ForEach(Supermarket.allCases) { market in
                            Text(market.displayName).tag(Supermarket?.some(market))
                        }
                    }
                    ChipGroup(
                        items: ProductCategory.allCases,
                        selection: $category,
                        fill: Palette.stock,
                        title: \.displayName,
                        systemImage: \.icon
                    )
                }
                Section("Quantities") {
                    Stepper("Units per package: \(unitsPerPackage)",
                            value: $unitsPerPackage, in: 1...99)
                    Stepper("Full packages: \(packages)", value: $packages, in: 0...999)
                    Stepper("Loose units: \(looseUnits)", value: $looseUnits, in: 0...999)
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
        var product = existing ?? StockProduct(name: "", packages: 0, looseUnits: 0, unitsPerPackage: 1)
        product.name            = name.trimmingCharacters(in: .whitespaces)
        product.unitsPerPackage = unitsPerPackage
        product.packages        = packages
        product.looseUnits      = looseUnits
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
