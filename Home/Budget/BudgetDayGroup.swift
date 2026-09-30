import Foundation

nonisolated struct BudgetDayGroup: Identifiable, Equatable {
    let day: Date
    let expenses: [BudgetExpense]

    var id: Date { day }

    static func groups(_ expenses: [BudgetExpense], in month: BudgetMonth,
                       calendar: Calendar) -> [BudgetDayGroup] {
        let inMonth = expenses.filter { $0.deletedAt == nil && month.contains($0.date, calendar: calendar) }
        return Dictionary(grouping: inMonth) { calendar.startOfDay(for: $0.date) }
            .map { BudgetDayGroup(day: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
}
