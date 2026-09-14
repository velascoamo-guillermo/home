import Foundation

nonisolated struct CalendarColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
}

nonisolated struct CalendarEventSnapshot: Identifiable, Hashable, Sendable {
    var itemIdentifier: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarID: String
    var calendarTitle: String
    var calendarColor: CalendarColor

    // Occurrences of a recurring event share one calendarItemIdentifier.
    var id: String { "\(itemIdentifier)@\(start.timeIntervalSinceReferenceDate)" }
}
