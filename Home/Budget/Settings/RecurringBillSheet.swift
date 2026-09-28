import SwiftUI

struct RecurringBillSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: RecurringExpense?

    @State private var name: String
    @State private var amountText: String
    @State private var categoryId: UUID?
    @State private var payerId: UUID?
    @State private var dayOfMonth: Int
    @State private var active: Bool
    @State private var errorMessage: String?

    init(existing: RecurringExpense?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _amountText = State(initialValue: existing.map { Money.editText(cents: $0.amountCents) } ?? "")
        _categoryId = State(initialValue: existing?.categoryId)
        _payerId = State(initialValue: existing?.payerId)
        _dayOfMonth = State(initialValue: existing?.dayOfMonth ?? 1)
        _active = State(initialValue: existing?.active ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Stepper("Day \(dayOfMonth) of each month", value: $dayOfMonth, in: 1...28)
                    Toggle("Active", isOn: $active)
                }
                Section("Category") {
                    ChipGroup(
                        items: ExpenseDraft.categoriesByUsage(store.budgetCategories,
                                                              expenses: store.budgetExpenses,
                                                              keeping: categoryId),
                        selection: Binding(
                            get: { store.budgetCategories.first { $0.id == categoryId } },
                            set: { categoryId = $0?.id }
                        ),
                        fill: Palette.budget,
                        title: \.name
                    )
                }
                Section("Paid by") {
                    Picker("Paid by", selection: $payerId) {
                        ForEach(store.budgetMembers) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if existing != nil {
                    Section {
                        Button("Delete bill", role: .destructive) { Task { await delete() } }
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
            .navigationTitle(existing == nil ? "New bill" : "Edit bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if payerId == nil { payerId = store.budgetMembers.first?.id }
            }
        }
    }

    static func makeBill(id: UUID, name: String, amountText: String, categoryId: UUID?,
                         payerId: UUID?, dayOfMonth: Int, active: Bool) throws -> RecurringExpense {
        try BudgetValidation.name(name)
        guard let cents = Money.parseCents(amountText) else { throw BudgetValidationError.invalidAmount }
        try BudgetValidation.amount(cents)
        guard let categoryId else { throw BudgetValidationError.missingCategory }
        guard let payerId else { throw BudgetValidationError.missingPayer }
        try BudgetValidation.dayOfMonth(dayOfMonth)
        return RecurringExpense(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                amountCents: cents, categoryId: categoryId, payerId: payerId,
                                dayOfMonth: dayOfMonth, active: active)
    }

    private func save() async {
        do {
            let bill = try Self.makeBill(id: existing?.id ?? UUID(), name: name, amountText: amountText,
                                         categoryId: categoryId, payerId: payerId,
                                         dayOfMonth: dayOfMonth, active: active)
            try await store.saveRecurringExpense(bill)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        guard let existing else { return }
        do {
            try await store.deleteRecurringExpense(existing)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
