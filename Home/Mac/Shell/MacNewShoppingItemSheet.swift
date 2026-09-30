#if os(macOS)
import SwiftUI

struct MacNewShoppingItemSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .onSubmit { Task { await add() } }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("New Shopping Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await add() } }
                        .disabled(ShoppingSession.quickAddProduct(named: name) == nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, idealWidth: 400, minHeight: 160)
    }

    private func add() async {
        guard let product = ShoppingSession.quickAddProduct(named: name) else { return }
        do {
            try await store.addProduct(product)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
