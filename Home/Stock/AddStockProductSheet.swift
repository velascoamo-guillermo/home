import SwiftUI

struct AddStockProductSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existing: StockProduct?

    @State private var name = ""
    @State private var icon = "shippingbox"
    @State private var unitsPerPackage = 1
    @State private var packages = 0
    @State private var looseUnits = 0
    @State private var supermarket: Supermarket?
    @State private var category: ProductCategory?
    @State private var showSymbolPicker = false

    private var isEditing: Bool { existing != nil }

    init(existing: StockProduct? = nil) {
        self.existing = existing
        if let p = existing {
            _name            = State(initialValue: p.name)
            _icon            = State(initialValue: p.icon)
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
                    Button {
                        showSymbolPicker = true
                    } label: {
                        HStack {
                            Text("Icon").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: icon).foregroundStyle(.tint)
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Picker("Supermarket", selection: $supermarket) {
                        Text("None").tag(Supermarket?.none)
                        ForEach(Supermarket.allCases) { market in
                            Text(market.displayName).tag(Supermarket?.some(market))
                        }
                    }
                    Picker("Category", selection: $category) {
                        Text("None").tag(ProductCategory?.none)
                        ForEach(ProductCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(ProductCategory?.some(cat))
                        }
                    }
                }
                Section("Quantities") {
                    Stepper("Units per package: \(unitsPerPackage)",
                            value: $unitsPerPackage, in: 1...99)
                    Stepper("Full packages: \(packages)", value: $packages, in: 0...999)
                    Stepper("Loose units: \(looseUnits)", value: $looseUnits, in: 0...999)
                }
            }
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
            .sheet(isPresented: $showSymbolPicker) {
                SFSymbolPicker(selection: $icon)
            }
        }
    }

    private func save() {
        var product = existing ?? StockProduct(name: "", icon: icon, packages: 0,
                                               looseUnits: 0, unitsPerPackage: 1)
        product.name            = name.trimmingCharacters(in: .whitespaces)
        product.icon            = icon
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
