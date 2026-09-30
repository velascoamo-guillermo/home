import SwiftUI

struct CategoryEditSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let category: BudgetCategory
    private let isNew: Bool

    @State private var name: String
    @State private var estimateText: String
    @State private var errorMessage: String?

    init(category: BudgetCategory, isNew: Bool) {
        self.category = category
        self.isNew = isNew
        _name = State(initialValue: category.name)
        _estimateText = State(initialValue: isNew ? "" : Money.editText(cents: category.estimateCents))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Monthly estimate")
                        Spacer()
                        TextField("0.00", text: $estimateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
                if !isNew {
                    Section {
                        Button("Delete category", role: .destructive) { Task { await delete() } }
                    } footer: {
                        Text("Categories with expenses or bills can only be archived.")
                    }
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .gradientCanvas()
            .navigationTitle(isNew ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() async {
        do {
            guard let cents = Money.parseCents(estimateText.isEmpty ? "0" : estimateText) else {
                throw BudgetValidationError.invalidAmount
            }
            var updated = category
            updated.name = name
            updated.estimateCents = cents
            try await store.saveBudgetCategory(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        do {
            try await store.deleteBudgetCategory(category)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
