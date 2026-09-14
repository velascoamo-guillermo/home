import Foundation

nonisolated struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let color: CalendarColor
}
