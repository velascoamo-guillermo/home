import Foundation

nonisolated struct BudgetHeroModel: Equatable {
    nonisolated struct Line: Equatable, Hashable {
        let title: String
        let amountText: String
        let accessibilityLabel: String
    }

    let lines: [Line]
    let ratioLine: String
    let remainingLine: String

    var isAllSquare: Bool { lines.isEmpty }

    var accessibilityLabel: String {
        isAllSquare ? "All square" : lines.map(\.accessibilityLabel).joined(separator: ", ")
    }

    init(summary: MonthSummary, locale: Locale) {
        lines = summary.settlement.map { transfer in
            let from = summary.memberName(transfer.fromMemberId)
            let to = summary.memberName(transfer.toMemberId)
            return Line(title: "\(from) → \(to)",
                        amountText: Money.format(cents: transfer.amountCents, locale: locale),
                        accessibilityLabel: "\(from) owes \(to) \(Money.spoken(cents: transfer.amountCents))")
        }
        ratioLine = summary.members
            .filter { !$0.isFormer }
            .map { "\($0.name) \($0.ratioPercent)%" }
            .joined(separator: " · ")
        remainingLine = "Remaining \(Money.format(cents: summary.remainingCents, locale: locale))"
            + " of \(Money.format(cents: summary.estimateCents, locale: locale))"
    }
}
