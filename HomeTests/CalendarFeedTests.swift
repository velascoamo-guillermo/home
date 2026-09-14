import Testing
import Foundation
@testable import Casita

@Suite("CalendarFeed") @MainActor struct CalendarFeedTests {
    private let week = DateInterval(start: AgendaFixtures.date(2026, 9, 13), end: AgendaFixtures.date(2026, 9, 22))
    private let nextWeek = DateInterval(start: AgendaFixtures.date(2026, 9, 20), end: AgendaFixtures.date(2026, 9, 29))
    private let blue = CalendarColor(red: 0, green: 0, blue: 1)

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "test.feed.\(UUID().uuidString)")!
    }
    private func event(_ title: String, calendar: String, day: Int = 16) -> CalendarEventSnapshot {
        let start = AgendaFixtures.date(2026, 9, day, 9)
        return CalendarEventSnapshot(itemIdentifier: title, title: title, start: start,
                                     end: start.addingTimeInterval(1800), isAllDay: false,
                                     calendarID: calendar, calendarTitle: calendar, calendarColor: blue)
    }
    private func info(_ id: String) -> CalendarInfo { CalendarInfo(id: id, title: id, color: blue) }

    @Test("full access: load fetches the interval and publishes events")
    func loadFullAccess() async {
        let source = FakeCalendarSource(events: [event("Standup", calendar: "work")])
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: defaults()))
        await feed.load(interval: week)
        #expect(feed.accessState == .fullAccess)
        #expect(feed.events.map(\.title) == ["Standup"])
        #expect(await source.requestedIntervals == [week])
        #expect(feed.showsBanner == false)
    }

    @Test("not determined: no events, banner shown")
    func loadNotDetermined() async {
        let source = FakeCalendarSource(state: .notDetermined, events: [event("Standup", calendar: "work")])
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: defaults()))
        await feed.load(interval: week)
        #expect(feed.events.isEmpty)
        #expect(feed.showsBanner)
    }

    @Test("restricted: no banner")
    func restricted() async {
        let feed = CalendarFeed(source: FakeCalendarSource(state: .restricted),
                                selection: CalendarSelectionStore(defaults: defaults()))
        await feed.load(interval: week)
        #expect(feed.showsBanner == false)
    }

    @Test("loading a new week replaces events")
    func weekChange() async {
        let source = FakeCalendarSource(events: [event("ThisWeek", calendar: "work", day: 16),
                                                 event("NextWeek", calendar: "work", day: 24)])
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: defaults()))
        await feed.load(interval: week)
        await feed.load(interval: nextWeek)
        #expect(feed.events.map(\.title) == ["NextWeek"])
    }

    @Test("granting access loads events and calendars")
    func grant() async {
        let source = FakeCalendarSource(state: .notDetermined, calendars: [info("work")],
                                        events: [event("Standup", calendar: "work")])
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: defaults()))
        await feed.load(interval: week)
        await feed.requestAccess()
        #expect(feed.accessState == .fullAccess)
        #expect(feed.events.map(\.title) == ["Standup"])
        #expect(feed.calendars == [info("work")])
    }

    @Test("refusing access switches the banner to denied")
    func refuse() async {
        let source = FakeCalendarSource(state: .notDetermined, grantsAccess: false)
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: defaults()))
        await feed.requestAccess()
        #expect(feed.accessState == .denied)
        #expect(feed.showsBanner)
    }

    @Test("excluding a calendar persists and is passed to the source")
    func exclude() async {
        let d = defaults()
        let source = FakeCalendarSource(events: [event("Standup", calendar: "work"),
                                                 event("Gym", calendar: "personal")])
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: d))
        await feed.load(interval: week)
        feed.setCalendar("work", included: false)
        #expect(feed.excludedIDs == ["work"])
        #expect(CalendarSelectionStore(defaults: d).excludedIDs() == ["work"])
        await feed.reload()
        #expect(feed.events.map(\.title) == ["Gym"])
        #expect(await source.requestedExclusions.last == ["work"])
    }

    @Test("loading calendars prunes excluded IDs that no longer exist")
    func prune() async {
        let d = defaults()
        CalendarSelectionStore(defaults: d).setExcludedIDs(["work", "gone"])
        let feed = CalendarFeed(source: FakeCalendarSource(calendars: [info("work"), info("personal")]),
                                selection: CalendarSelectionStore(defaults: d))
        await feed.reload()
        await feed.loadCalendars()
        #expect(feed.excludedIDs == ["work"])
        #expect(CalendarSelectionStore(defaults: d).excludedIDs() == ["work"])
    }

    @Test("dismissing the banner hides it and persists")
    func dismiss() async {
        let d = defaults()
        let feed = CalendarFeed(source: FakeCalendarSource(state: .notDetermined),
                                selection: CalendarSelectionStore(defaults: d))
        await feed.reload()
        feed.dismissBanner()
        #expect(feed.showsBanner == false)
        #expect(CalendarSelectionStore(defaults: d).isBannerDismissed)
    }

    @Test("a store change notification triggers a refetch")
    func changeRefetches() async throws {
        let source = FakeCalendarSource(events: [event("Standup", calendar: "work")])
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: defaults()))
        await feed.load(interval: week)
        let observer = Task { await feed.observeChanges() }
        defer { observer.cancel() }

        await source.emitChange()
        for _ in 0..<100 {
            if await source.requestedIntervals.count >= 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await source.requestedIntervals.count == 2)
    }

    @Test("setCalendar alone eventually refetches with the new exclusion")
    func setCalendarRefetchesWithoutExplicitReload() async throws {
        let source = FakeCalendarSource(events: [event("Standup", calendar: "work"),
                                                 event("Gym", calendar: "personal")])
        let feed = CalendarFeed(source: source, selection: CalendarSelectionStore(defaults: defaults()))
        await feed.load(interval: week)
        feed.setCalendar("work", included: false)

        for _ in 0..<100 {
            if feed.events.map(\.title) == ["Gym"] { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(feed.events.map(\.title) == ["Gym"])
        #expect(await source.requestedExclusions.last == ["work"])
    }

    @Test("full access: banner does not flash before the first reload resolves")
    func noBannerFlashFullAccess() async {
        let feed = CalendarFeed(source: FakeCalendarSource(state: .fullAccess),
                                selection: CalendarSelectionStore(defaults: defaults()))
        #expect(feed.showsBanner == false)
        await feed.reload()
        #expect(feed.showsBanner == false)
    }

    @Test("not determined: banner is suppressed until the first reload resolves, then shown")
    func noBannerFlashNotDetermined() async {
        let feed = CalendarFeed(source: FakeCalendarSource(state: .notDetermined),
                                selection: CalendarSelectionStore(defaults: defaults()))
        #expect(feed.showsBanner == false)
        await feed.reload()
        #expect(feed.showsBanner)
    }
}
