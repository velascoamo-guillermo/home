import Testing
import Foundation
@testable import Casita

@Suite("AgendaWeek") @MainActor struct AgendaWeekTests {
    private let today = AgendaFixtures.today

    @Test("Monday-first week containing Wednesday 16 Sep")
    func mondayFirst() {
        let days = AgendaWeek.days(containing: today, calendar: AgendaFixtures.calendar)
        #expect(days.count == 7)
        #expect(days.first == AgendaFixtures.date(2026, 9, 14))
        #expect(days.last == AgendaFixtures.date(2026, 9, 20))
    }

    @Test("Sunday-first week containing Wednesday 16 Sep")
    func sundayFirst() {
        let cal = AgendaFixtures.makeCalendar(firstWeekday: 1)
        let days = AgendaWeek.days(containing: today, calendar: cal)
        #expect(days.first == AgendaFixtures.date(2026, 9, 13))
        #expect(days.last == AgendaFixtures.date(2026, 9, 19))
    }

    @Test("fetch interval pads the week by one full day on each side")
    func fetchInterval() {
        let interval = AgendaWeek.fetchInterval(containing: today, calendar: AgendaFixtures.calendar)
        #expect(interval.start == AgendaFixtures.date(2026, 9, 13))
        #expect(interval.end == AgendaFixtures.date(2026, 9, 22))
    }

    @Test("shifting by a week lands on the same weekday")
    func shifted() {
        #expect(AgendaWeek.shifted(today, weeks: 1, calendar: AgendaFixtures.calendar) == AgendaFixtures.date(2026, 9, 23))
        #expect(AgendaWeek.shifted(today, weeks: -1, calendar: AgendaFixtures.calendar) == AgendaFixtures.date(2026, 9, 9))
    }

    @Test("dayID uses the calendar's time zone")
    func dayID() {
        #expect(AgendaWeek.dayID(AgendaFixtures.date(2026, 9, 16, 23, 30), calendar: AgendaFixtures.calendar) == "2026-09-16")
    }
}
