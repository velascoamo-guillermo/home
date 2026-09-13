import Foundation

nonisolated protocol CalendarEventSource: Sendable {
    var changes: AsyncStream<Void> { get }
    func accessState() async -> CalendarAccessState
    func requestAccess() async -> Bool
    func calendars() async -> [CalendarInfo]
    func events(in interval: DateInterval, excluding excludedIDs: Set<String>) async -> [CalendarEventSnapshot]
}
