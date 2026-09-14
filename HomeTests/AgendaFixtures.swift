import Foundation

enum AgendaFixtures {
    static let calendar: Calendar = makeCalendar(firstWeekday: 2)

    static func makeCalendar(firstWeekday: Int) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        c.firstWeekday = firstWeekday
        return c
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Wednesday 16 September 2026.
    static let today = date(2026, 9, 16)
}
