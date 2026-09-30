import SwiftUI

struct MemberIncomeRow: View {
    @Environment(SupabaseStore.self) private var store
    let line: MemberLine
    let month: BudgetMonth

    @State private var name: String
    @State private var incomeText: String
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name, income }

    init(line: MemberLine, month: BudgetMonth) {
        self.line = line
        self.month = month
        _name = State(initialValue: line.name)
        _incomeText = State(initialValue: Money.editText(cents: line.incomeCents))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: $name)
                .font(.headline)
                .focused($focus, equals: .name)
                .submitLabel(.done)
                .onSubmit { Task { await commitName() } }
                .accessibilityLabel("Member name")
            HStack {
                Text("Income")
                Spacer()
                TextField("0.00", text: $incomeText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focus, equals: .income)
                    .onSubmit { Task { await commitIncome() } }
                    .frame(width: 120)
                    .accessibilityLabel("\(line.name) income")
            }
            if line.incomeCarriedOver {
                Text("Carried over from an earlier month")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                // Only the focused row contributes, otherwise every row adds its own Done button.
                if focus != nil {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
        }
        .onChange(of: focus) { old, _ in
            if old == .income { Task { await commitIncome() } }
            if old == .name { Task { await commitName() } }
        }
        .onChange(of: line.name) { _, incoming in
            name = Self.resynced(local: name, incoming: incoming, isEditing: focus == .name)
        }
        .onChange(of: line.incomeCents) { _, incoming in
            incomeText = Self.resynced(local: incomeText, incoming: Money.editText(cents: incoming),
                                       isEditing: focus == .income)
        }
        .onDisappear {
            Task {
                await commitName()
                await commitIncome()
            }
        }
    }

    static func resynced(local: String, incoming: String, isEditing: Bool) -> String {
        isEditing ? local : incoming
    }

    static func nameToSave(text: String, current: MemberLine) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == current.name ? nil : trimmed
    }

    static func incomeToSave(text: String, current: MemberLine) throws -> Int? {
        guard let cents = Money.parseCents(text) else { throw BudgetValidationError.invalidAmount }
        try BudgetValidation.nonNegativeAmount(cents)
        return cents == current.incomeCents ? nil : cents
    }

    private func commitIncome() async {
        do {
            guard let cents = try Self.incomeToSave(text: incomeText, current: line) else { return }
            try await store.setBudgetIncome(memberId: line.id, month: month, amountCents: cents)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func commitName() async {
        guard let newName = Self.nameToSave(text: name, current: line),
              let member = store.budgetMembers.first(where: { $0.id == line.id }) else { return }
        do {
            try await store.renameBudgetMember(member, to: newName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
