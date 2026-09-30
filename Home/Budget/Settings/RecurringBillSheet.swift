import SwiftUI

struct RecurringBillSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: RecurringExpense?

    @State private var draft: RecurringBillDraft
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(existing: RecurringExpense?) {
        self.existing = existing
        _draft = State(initialValue: RecurringBillDraft(existing: existing))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $draft.name)
                    TextField("Amount", text: $draft.amountText)
                        .platformKeyboard(.decimalPad)
                    Stepper("Day \(draft.dayOfMonth) of each month", value: $draft.dayOfMonth, in: 1...28)
                    Toggle("Active", isOn: $draft.active)
                }
                Section("Category") {
                    ChipGroup(
                        items: ExpenseDraft.categoriesByUsage(store.budgetCategories,
                                                              expenses: store.budgetExpenses,
                                                              keeping: draft.categoryId),
                        selection: Binding(
                            get: { store.budgetCategories.first { $0.id == draft.categoryId } },
                            set: { draft.categoryId = $0?.id }
                        ),
                        fill: Palette.budget,
                        title: \.name
                    )
                }
                Section("Paid by") {
                    Picker("Paid by", selection: $draft.payerId) {
                        ForEach(store.budgetMembers) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if existing != nil {
                    Section {
                        Button("Delete bill", role: .destructive) {
                            isSaving = true
                            Task { await delete() }
                        }
                        .disabled(isSaving)
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
            .navigationTitle(draft.isNew ? "New bill" : "Edit bill")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if draft.payerId == nil { draft.payerId = store.budgetMembers.first?.id }
            }
        }
        .platformSheet()
    }

    private func save() async {
        defer { isSaving = false }
        do {
            try await store.saveRecurringExpense(try draft.makeBill())
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        defer { isSaving = false }
        guard let existing else { return }
        do {
            try await store.deleteRecurringExpense(existing)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
