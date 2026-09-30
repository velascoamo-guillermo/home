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
            HStack {
                Text("Income")
                Spacer()
                TextField("0.00", text: $incomeText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focus, equals: .income)
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
        .onChange(of: focus) { old, _ in
            if old == .income { Task { await commitIncome() } }
            if old == .name { Task { await commitName() } }
        }
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
        guard name != line.name,
              let member = store.budgetMembers.first(where: { $0.id == line.id }) else { return }
        do {
            try await store.renameBudgetMember(member, to: name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
