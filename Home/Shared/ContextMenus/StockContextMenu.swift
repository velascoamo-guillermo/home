import SwiftUI

struct StockContextMenu: View {
    let product: StockProduct
    var onDeleteRequest: ((StockProduct) -> Void)? = nil

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        Section("Level") {
            ForEach(Array(StockLevel.allCases.reversed()), id: \.self) { level in
                Button {
                    guard level != product.level else { return }
                    Task { try? await store.updateProduct(product.withLevel(level)) }
                } label: {
                    if level == product.level {
                        Label(level.displayName, systemImage: "checkmark")
                    } else {
                        Text(level.displayName)
                    }
                }
            }
        }

        if !product.isOnShoppingList {
            Button {
                var updated = product
                updated.needed = true
                Task { try? await store.updateProduct(updated) }
            } label: { Label("Add to shopping", systemImage: "cart.badge.plus") }
        }

        Button(role: .destructive) {
            if let onDeleteRequest {
                onDeleteRequest(product)
            } else {
                Task { try? await store.deleteProduct(product) }
            }
        } label: { Label("Delete", systemImage: "trash") }
    }
}

extension View {
    func productDeleteDialog(_ product: Binding<StockProduct?>) -> some View {
        modifier(ProductDeleteDialog(product: product))
    }
}

struct ProductDeleteDialog: ViewModifier {
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
            Text(ProductDeleteDialog.deleteMessage(taskCount: n))
        }
    }

    nonisolated static func deleteMessage(taskCount: Int) -> String {
        if taskCount == 0 {
            return "This can't be undone."
        } else {
            return "Unlinks \(taskCount) task\(taskCount == 1 ? "" : "s") pointing at it."
        }
    }
}
