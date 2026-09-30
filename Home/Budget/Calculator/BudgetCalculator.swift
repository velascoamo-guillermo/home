import Foundation

nonisolated struct BudgetCalculator {
    static let formerMemberName = "Former member"

    let members: [BudgetMember]
    let categories: [BudgetCategory]
    let incomes: [BudgetIncome]
    let recurring: [RecurringExpense]
    let expenses: [BudgetExpense]
    let calendar: Calendar

    func summary(for month: BudgetMonth, today: Date) -> MonthSummary {
        let monthExpenses = expenses.filter { $0.deletedAt == nil && month.contains($0.date, calendar: calendar) }
        let total = monthExpenses.reduce(0) { $0 + $1.amountCents }
        let live = categories.filter { $0.deletedAt == nil }
        let estimate = live.filter { !$0.archived }.reduce(0) { $0 + $1.estimateCents }
        let lines = memberLines(month: month, expenses: monthExpenses, total: total)
        return MonthSummary(
            month: month,
            totalCents: total,
            estimateCents: estimate,
            remainingCents: estimate - total,
            categories: categoryLines(live, expenses: monthExpenses),
            members: lines,
            settlement: Self.settle(lines),
            pendingRecurring: pending(month: month, today: today)
        )
    }

    // MARK: Members

    private func memberLines(month: BudgetMonth, expenses: [BudgetExpense], total: Int) -> [MemberLine] {
        let active = members.filter { $0.deletedAt == nil }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
        let paid = Dictionary(grouping: expenses, by: \.payerId)
            .mapValues { $0.reduce(0) { $0 + $1.amountCents } }
        let resolved = active.map { income(for: $0.id, month: month) }
        let totalIncome = resolved.reduce(0) { $0 + $1.cents }
        let weights = totalIncome == 0 ? active.map { _ in 1 } : resolved.map(\.cents)
        let weightSum = weights.reduce(0, +)
        let shares = Self.split(total, weights: weights, order: active.map(\.sortOrder))

        var lines = active.indices.map { i in
            let p = paid[active[i].id] ?? 0
            return MemberLine(
                id: active[i].id, name: active[i].name, isFormer: false,
                sortOrder: active[i].sortOrder,
                incomeCents: resolved[i].cents, incomeCarriedOver: resolved[i].carriedOver,
                ratioPercent: Self.percent(weights[i], of: weightSum),
                shareCents: shares[i], paidCents: p, balanceCents: p - shares[i],
                savingsCents: resolved[i].cents - shares[i]
            )
        }
        let activeIds = Set(active.map(\.id))
        let formerIds = paid.keys.filter { !activeIds.contains($0) }.sorted { $0.uuidString < $1.uuidString }
        for id in formerIds {
            let p = paid[id] ?? 0
            lines.append(MemberLine(
                id: id, name: Self.formerMemberName, isFormer: true, sortOrder: .max,
                incomeCents: 0, incomeCarriedOver: false, ratioPercent: 0,
                shareCents: 0, paidCents: p, balanceCents: p, savingsCents: 0
            ))
        }
        return lines
    }

    private func income(for memberId: UUID, month: BudgetMonth) -> (cents: Int, carriedOver: Bool) {
        let candidates = incomes.filter {
            $0.deletedAt == nil && $0.memberId == memberId && $0.month <= month.key
        }
        guard let latest = candidates.max(by: { $0.month < $1.month }) else { return (0, false) }
        return (latest.amountCents, latest.month != month.key)
    }

    /// Largest-remainder apportionment: floor each share, then hand the leftover cents one
    /// by one to the largest fractional remainders (ties → lower sort order).
    static func split(_ total: Int, weights: [Int], order: [Int]) -> [Int] {
        let sum = weights.reduce(0, +)
        guard sum > 0 else { return weights.map { _ in 0 } }
        var shares = weights.map { total * $0 / sum }
        let remainders = weights.map { (total * $0) % sum }
        let leftover = total - shares.reduce(0, +)
        let ranked = weights.indices.sorted { a, b in
            remainders[a] != remainders[b] ? remainders[a] > remainders[b] : order[a] < order[b]
        }
        for i in ranked.prefix(leftover) { shares[i] += 1 }
        return shares
    }

    private static func percent(_ weight: Int, of sum: Int) -> Int {
        guard sum > 0 else { return 0 }
        return (weight * 200 + sum) / (2 * sum)
    }

    // MARK: Settlement

    private nonisolated struct Party {
        let id: UUID
        let order: Int
        var amount: Int
    }

    static func settle(_ lines: [MemberLine]) -> [Transfer] {
        let rank: (Party, Party) -> Bool = { a, b in
            if a.amount != b.amount { return a.amount > b.amount }
            if a.order != b.order { return a.order < b.order }
            return a.id.uuidString < b.id.uuidString
        }
        var debtors = lines.filter { $0.balanceCents < 0 }
            .map { Party(id: $0.id, order: $0.sortOrder, amount: -$0.balanceCents) }
        var creditors = lines.filter { $0.balanceCents > 0 }
            .map { Party(id: $0.id, order: $0.sortOrder, amount: $0.balanceCents) }
        var transfers: [Transfer] = []
        while !debtors.isEmpty, !creditors.isEmpty {
            debtors.sort(by: rank)
            creditors.sort(by: rank)
            let amount = min(debtors[0].amount, creditors[0].amount)
            transfers.append(Transfer(fromMemberId: debtors[0].id, toMemberId: creditors[0].id,
                                      amountCents: amount))
            debtors[0].amount -= amount
            creditors[0].amount -= amount
            debtors.removeAll { $0.amount == 0 }
            creditors.removeAll { $0.amount == 0 }
        }
        return transfers
    }

    // MARK: Categories

    private func categoryLines(_ live: [BudgetCategory], expenses: [BudgetExpense]) -> [CategoryLine] {
        let actual = Dictionary(grouping: expenses, by: \.categoryId)
            .mapValues { $0.reduce(0) { $0 + $1.amountCents } }
        let byOrder: (BudgetCategory, BudgetCategory) -> Bool = {
            ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name)
        }
        let active = live.filter { !$0.archived }.sorted(by: byOrder)
        let archived = live.filter { $0.archived && actual[$0.id] != nil }.sorted(by: byOrder)
        return (active + archived).map { CategoryLine(category: $0, actualCents: actual[$0.id] ?? 0) }
    }

    // MARK: Recurring

    /// A bill is confirmed for a month by its deterministic expense id, not by the expense
    /// date: a bill paid late is logged in the month it was paid but still settles its own month.
    private func pending(month: BudgetMonth, today: Date) -> [RecurringExpense] {
        let current = BudgetMonth(date: today, calendar: calendar)
        guard month <= current else { return [] }
        let live = Set(expenses.filter { $0.deletedAt == nil }.map(\.id))
        let todayDay = calendar.component(.day, from: today)
        return recurring
            .filter { bill in
                bill.deletedAt == nil && bill.active
                    && !live.contains(BudgetIDs.recurringExpense(recurringId: bill.id, month: month))
                    && (month < current || bill.dayOfMonth <= todayDay)
            }
            .sorted { ($0.dayOfMonth, $0.name) < ($1.dayOfMonth, $1.name) }
    }
}
