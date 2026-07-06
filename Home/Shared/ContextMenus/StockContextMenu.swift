import SwiftUI

struct StockContextMenu: View {
    let product: StockProduct

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
            Task { try? await store.deleteProduct(product) }
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
