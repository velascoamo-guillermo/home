import Foundation

nonisolated struct BudgetMonth: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1)
    }

    init?(key: String) {
        let parts = key.split(separator: "-")
        guard key.count == 7, parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        self.init(year: y, month: m)
    }

    var key: String { String(format: "%04d-%02d", year, month) }

    var next: BudgetMonth {
        month == 12 ? BudgetMonth(year: year + 1, month: 1) : BudgetMonth(year: year, month: month + 1)
    }

    var previous: BudgetMonth {
        month == 1 ? BudgetMonth(year: year - 1, month: 12) : BudgetMonth(year: year, month: month - 1)
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        BudgetMonth(date: date, calendar: calendar) == self
    }

    func date(day: Int, calendar: Calendar) -> Date {
        let clamped = min(max(day, 1), 28)
        return calendar.date(from: DateComponents(year: year, month: month, day: clamped, hour: 12))
            ?? .distantPast
    }

    func title(locale: Locale, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL yyyy"
        let raw = formatter.string(from: date(day: 1, calendar: calendar))
        return raw.prefix(1).uppercased(with: locale) + raw.dropFirst()
    }

    static func < (lhs: BudgetMonth, rhs: BudgetMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
