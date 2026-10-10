import SwiftUI

struct BudgetHeroCard: View {
    let model: BudgetHeroModel

    var body: some View {
        VStack(spacing: 8) {
            if model.isAllSquare {
                Text("All square")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
            } else {
                ForEach(model.lines, id: \.self) { line in
                    Text(line.title)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text(line.amountText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                        .contentTransition(.numericText())
                }
            }
            Text(model.ratioLine)
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Palette.budget, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityLabel)
        .accessibilityValue(model.ratioLine)
        .accessibilityIdentifier("budgetHero")
    }
}
