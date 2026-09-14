import Foundation

enum AgendaWeek {
    static func days(containing day: Date, calendar: Calendar) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: day) else {
            return [calendar.startOfDay(for: day)]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    // Padded by a day on each side so events crossing midnight at the week edges are fetched.
    static func fetchInterval(containing day: Date, calendar: Calendar) -> DateInterval {
        let week = days(containing: day, calendar: calendar)
        let first = week.first ?? calendar.startOfDay(for: day)
        let last = week.last ?? first
        let start = calendar.date(byAdding: .day, value: -1, to: first) ?? first
        let end = calendar.date(byAdding: .day, value: 2, to: last) ?? last
        return DateInterval(start: start, end: end)
    }

    static func shifted(_ day: Date, weeks: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: calendar.startOfDay(for: day)) ?? day
    }

    static func dayID(_ day: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
