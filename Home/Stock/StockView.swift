import SwiftUI

struct StockView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var editing: StockProduct? = nil
    @State private var productToDelete: StockProduct? = nil
    @State private var filter: StockListModel.Filter = .all
    @State private var searchText = ""

    var body: some View {
        Group {
            if store.stockProducts.isEmpty {
                ContentUnavailableView(
                    "No Stock",
                    systemImage: "shippingbox",
                    description: Text("Add products you restock and link them to tasks.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gradientCanvas()
            } else {
                list(StockListModel(products: store.stockProducts, filter: filter, query: searchText))
            }
        }
        .navigationTitle("Stock")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search stock")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add product", systemImage: "plus") { showAdd = true }
                    .accessibilityLabel("Add product")
            }
        }
        .sheet(isPresented: $showAdd) { AddStockProductSheet() }
        .sheet(item: $editing) { product in AddStockProductSheet(existing: product) }
        .productDeleteDialog($productToDelete)
    }

    private func list(_ model: StockListModel) -> some View {
        List {
            Section {
                HStack(spacing: 8) {
                    ForEach(model.visibleFilters, id: \.self) { option in
                        Chip(title: model.title(for: option), fill: fill(for: option),
                             isSelected: model.effectiveFilter == option) {
                            filter = StockListModel.toggled(model.effectiveFilter, tapped: option)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

            if model.groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(model.groups) { group in
                    Section {
                        ForEach(group.products) { product in
                            row(product)
                        }
                    } header: {
                        Label(group.title, systemImage: group.icon)
                    }
                }
            }
        }
        .flatListStyle()
        .animation(.spring(duration: 0.35), value: model.groups)
    }

    private func row(_ product: StockProduct) -> some View {
        Button { editing = product } label: {
            StockProductRow(product: product, onSetLevel: { setLevel($0, for: product) })
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stockRow-\(product.name)")
        .pastelRow(Palette.stock)
        .contextMenu { StockContextMenu(product: product, onDeleteRequest: { productToDelete = $0 }) }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { try? await store.replenish(product) }
            } label: { Label("Bought", systemImage: "cart.fill") }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                productToDelete = product
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func setLevel(_ level: StockLevel, for product: StockProduct) {
        guard level != product.level else { return }
        Task { try? await store.updateProduct(product.withLevel(level)) }
    }

    private func fill(for filter: StockListModel.Filter) -> Color {
        switch filter {
        case .all: Palette.stock
        case .out: Palette.pets
        case .low: Palette.meals
        }
    }
}

#Preview {
    NavigationStack {
        StockView()
    }
    .environment(SupabaseStore())
}
