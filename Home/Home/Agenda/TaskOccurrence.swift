import Foundation

enum TaskOccurrence: Hashable {
    case real
    case overdue(days: Int)
    case projected

    static func of(_ task: HouseholdTask, on day: Date, today: Date, calendar: Calendar) -> TaskOccurrence? {
        let day = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: today)
        let due = calendar.startOfDay(for: task.nextDueDate)

        if day < today { return nil }
        if day == today, due < today { return .overdue(days: days(from: due, to: today, calendar: calendar)) }
        if due == day { return .real }
        guard day > due, task.intervalDays > 0 else { return nil }
        // Completing an overdue task re-anchors its schedule to the completion day, so repeats count from today.
        let anchor = max(due, today)
        return days(from: anchor, to: day, calendar: calendar) % task.intervalDays == 0 ? .projected : nil
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
