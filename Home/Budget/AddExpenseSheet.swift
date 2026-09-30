import SwiftUI

struct AddExpenseSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ExpenseDraft.lastPayerKey) private var lastPayerId = ""

    @State private var draft: ExpenseDraft
    @State private var errorMessage: String?
    @State private var isSaving = false
    @FocusState private var amountFocused: Bool

    init(draft: ExpenseDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $draft.amountText)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .accessibilityLabel("Amount")
                        .accessibilityIdentifier("expenseAmount")
                }
                // Kept right below the amount field (rather than after every other
                // section) so it stays inside the visible viewport even while the
                // decimal keypad covers the lower half of the sheet — an off-screen
                // Form row isn't guaranteed to be materialized as an accessibility
                // element, which would make the inline error unreachable/untestable.
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("expenseError")
                    }
                }
                Section("Category") {
                    ChipGroup(
                        items: ExpenseDraft.categoriesByUsage(store.budgetCategories,
                                                              expenses: store.budgetExpenses,
                                                              keeping: draft.categoryId),
                        selection: categoryBinding,
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
                Section {
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    TextField("Name (optional)", text: $draft.name)
                }
            }
            .scrollContentBackground(.hidden)
            .gradientCanvas()
            .navigationTitle(draft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { amountFocused = true }
        }
    }

    private var categoryBinding: Binding<BudgetCategory?> {
        Binding(
            get: { store.budgetCategories.first { $0.id == draft.categoryId } },
            set: { draft.categoryId = $0?.id }
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let expense = try draft.makeExpense()
            try await store.saveBudgetExpense(expense)
            lastPayerId = expense.payerId.uuidString
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
