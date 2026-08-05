import SwiftUI

struct StockContextMenu: View {
    let product: StockProduct
    var onDeleteRequest: ((StockProduct) -> Void)? = nil

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        Menu {
            Button {
                Task { try? await store.replenish(product) }
            } label: { Label("Replenish", systemImage: "plus.square.on.square") }

            consume(units: 1, title: "Consume 1")
            consume(units: 2, title: "Consume 2")
            consume(units: 5, title: "Consume 5")

            Button {
                Task { try? await store.updateProduct(product.emptied()) }
            } label: { Label("Empty", systemImage: "trash.slash") }
        } label: { Label("Adjust stock", systemImage: "slider.horizontal.3") }

        Button(role: .destructive) {
            if store.householdTasks.contains(where: { $0.productId == product.id }),
               let onDeleteRequest {
                onDeleteRequest(product)
            } else {
                Task { try? await store.deleteProduct(product) }
            }
        } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private func consume(units: Int, title: String) -> some View {
        if let consumed = product.consuming(units: units) {
            Button {
                Task { try? await store.updateProduct(consumed) }
            } label: { Label(title, systemImage: "minus.circle") }
        }
    }
}

extension View {
    func productDeleteDialog(_ product: Binding<StockProduct?>) -> some View {
        modifier(ProductDeleteDialog(product: product))
    }
}

private struct ProductDeleteDialog: ViewModifier {
    @Binding var product: StockProduct?
    @Environment(SupabaseStore.self) private var store

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete \(product?.name ?? "")?",
            isPresented: Binding(
                get: { product != nil },
                set: { if !$0 { product = nil } }
            ),
            titleVisibility: .visible,
            presenting: product
        ) { p in
            Button("Delete", role: .destructive) {
                Task { try? await store.deleteProduct(p) }
            }
        } message: { p in
            let n = store.householdTasks.count { $0.productId == p.id }
            Text("Unlinks \(n) task\(n == 1 ? "" : "s") pointing at it.")
        }
    }
}
