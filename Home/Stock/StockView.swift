import SwiftUI

struct StockView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var editing: StockProduct? = nil

    var body: some View {
        Group {
            if store.stockProducts.isEmpty {
                ContentUnavailableView(
                    "No Stock",
                    systemImage: "shippingbox",
                    description: Text("Add products you restock and link them to tasks.")
                )
            } else {
                List {
                    ForEach(store.stockProducts) { product in
                        Button { editing = product } label: {
                            StockProductRow(product: product)
                        }
                        .buttonStyle(.plain)
                        .glassRow()
                        .contextMenu { StockContextMenu(product: product) }
                    }
                }
                .glassListStyle()
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
    }
}

#Preview {
    StockView()
        .environment(SupabaseStore())
}
