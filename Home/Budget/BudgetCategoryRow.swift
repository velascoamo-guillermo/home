import SwiftUI

struct BudgetCategoryRow: View {
    let line: CategoryLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(line.category.name)
                Spacer()
                Text("\(Money.format(cents: line.actualCents)) / \(Money.format(cents: line.estimateCents))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(line.isOverBudget ? Color.red : Palette.inkSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.canvasMid)
                    Capsule()
                        .fill(line.isOverBudget ? Color.red : Palette.accent)
                        .frame(width: geo.size.width * Self.fillFraction(line))
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.category.name)
        .accessibilityValue(Self.accessibilityValue(for: line, locale: .current))
    }

    /// Layout-only ratio; money itself never leaves Int cents.
    private static func fillFraction(_ line: CategoryLine) -> CGFloat {
        guard line.estimateCents > 0 else { return line.actualCents > 0 ? 1 : 0 }
        return min(CGFloat(line.actualCents) / CGFloat(line.estimateCents), 1)
    }

    static func accessibilityValue(for line: CategoryLine, locale: Locale) -> String {
        let base = "\(Money.format(cents: line.actualCents, locale: locale)) of "
            + Money.format(cents: line.estimateCents, locale: locale)
        return line.isOverBudget ? base + ", over budget" : base
    }
}
