import Foundation

nonisolated protocol CalendarEventSource: Sendable {
    // One stream for the source's whole lifetime: consume it from exactly one task that
    // lives as long as the source. Cancelling that task ends observation permanently —
    // there is no second consumer to take over.
    var changes: AsyncStream<Void> { get }
    func accessState() async -> CalendarAccessState
    func requestAccess() async -> Bool
    func calendars() async -> [CalendarInfo]
    func events(in interval: DateInterval, excluding excludedIDs: Set<String>) async -> [CalendarEventSnapshot]
}
