import SwiftUI

struct StockView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var editing: StockProduct? = nil
    @State private var productToDelete: StockProduct? = nil

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
                List {
                    ForEach(store.stockProducts) { product in
                        Button { editing = product } label: {
                            StockProductRow(product: product, onConsume: { consumeOne(product) })
                        }
                        .buttonStyle(.plain)
                        .pastelRow(Palette.stock)
                        .contextMenu { StockContextMenu(product: product, onDeleteRequest: { productToDelete = $0 }) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if product.totalUnits > 0 {
                                Button { consumeOne(product) } label: {
                                    Label("Consume 1", systemImage: "minus.circle")
                                }
                                .tint(.orange)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { try? await store.deleteProduct(product) }
                            } label: { Label("Delete", systemImage: "trash") }
                            Button {
                                Task { try? await store.replenish(product) }
                            } label: { Label("Replenish", systemImage: "plus.square.on.square") }
                        }
                    }
                }
                .flatListStyle()
            }
        }
        .navigationTitle("Stock")
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

    private func consumeOne(_ product: StockProduct) {
        guard let consumed = product.consumingOneUnit() else { return }
        Task { try? await store.updateProduct(consumed) }
    }
}

#Preview {
    StockView()
        .environment(SupabaseStore())
}
