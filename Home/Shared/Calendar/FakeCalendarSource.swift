import Foundation

// Deterministic source for UI-test launch mode and unit tests; never touches EventKit.
actor FakeCalendarSource: CalendarEventSource {
    nonisolated let changes: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    private var state: CalendarAccessState
    private let grantsAccess: Bool
    private let calendarList: [CalendarInfo]
    private let allEvents: [CalendarEventSnapshot]
    private(set) var requestedIntervals: [DateInterval] = []
    private(set) var requestedExclusions: [Set<String>] = []

    init(state: CalendarAccessState = .fullAccess, grantsAccess: Bool = true,
         calendars: [CalendarInfo] = [], events: [CalendarEventSnapshot] = []) {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.changes = stream
        self.continuation = continuation
        self.state = state
        self.grantsAccess = grantsAccess
        self.calendarList = calendars
        self.allEvents = events
    }

    func accessState() -> CalendarAccessState { state }

    func requestAccess() -> Bool {
        if grantsAccess { state = .fullAccess }
        return grantsAccess
    }

    func calendars() -> [CalendarInfo] { calendarList }

    func events(in interval: DateInterval, excluding excludedIDs: Set<String>) -> [CalendarEventSnapshot] {
        requestedIntervals.append(interval)
        requestedExclusions.append(excludedIDs)
        guard state == .fullAccess else { return [] }
        return allEvents.filter {
            !excludedIDs.contains($0.calendarID) && $0.start < interval.end && $0.end > interval.start
        }
    }

    func emitChange() {
        continuation.yield(())
    }

    static func uiTestFixture(now: Date = .now, calendar: Calendar = .current) -> FakeCalendarSource {
        let color = CalendarColor(red: 0.35, green: 0.55, blue: 0.95)
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        return FakeCalendarSource(
            calendars: [CalendarInfo(id: "fixture-work", title: "Fixture Work", color: color)],
            events: [CalendarEventSnapshot(
                itemIdentifier: "fixture-standup", title: "Fixture Standup",
                start: start, end: start.addingTimeInterval(1800), isAllDay: false,
                calendarID: "fixture-work", calendarTitle: "Fixture Work", calendarColor: color)]
        )
    }
}
