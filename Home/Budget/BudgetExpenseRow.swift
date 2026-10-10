import SwiftUI

struct BudgetExpenseRow: View {
    let expense: BudgetExpense
    let categoryName: String
    let payerName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name.isEmpty ? categoryName : expense.name)
                    .foregroundStyle(Palette.ink)
                Text(expense.name.isEmpty ? payerName : "\(categoryName) · \(payerName)")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
            Text(Money.format(cents: expense.amountCents))
                .font(.body.monospacedDigit())
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}
