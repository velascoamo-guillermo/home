import Testing
import Foundation
@testable import Casita

@Suite("TaskOccurrence") @MainActor struct TaskOccurrenceTests {
    private let cal = AgendaFixtures.calendar
    private let today = AgendaFixtures.today
    private func d(_ m: Int, _ day: Int, _ h: Int = 0, year: Int = 2026) -> Date {
        AgendaFixtures.date(year, m, day, h)
    }
    private func task(due: Date, every interval: Int = 7) -> HouseholdTask {
        HouseholdTask(title: "T", intervalDays: interval, nextDueDate: due)
    }

    @Test("real on its due day, today or later")
    func real() {
        #expect(TaskOccurrence.of(task(due: d(9, 16)), on: today, today: today, calendar: cal) == .real)
        #expect(TaskOccurrence.of(task(due: d(9, 18)), on: d(9, 18), today: today, calendar: cal) == .real)
    }

    @Test("time of day on the due date is ignored")
    func ignoresTime() {
        #expect(TaskOccurrence.of(task(due: d(9, 17, 23)), on: d(9, 17), today: today, calendar: cal) == .real)
    }

    @Test("overdue only on today, with day count")
    func overdue() {
        let late = task(due: d(9, 13), every: 30)
        #expect(TaskOccurrence.of(late, on: today, today: today, calendar: cal) == .overdue(days: 3))
        #expect(TaskOccurrence.of(late, on: d(9, 17), today: today, calendar: cal) == nil)
    }

    @Test("overdue tasks project from today, where completing them re-anchors the schedule")
    func overdueProjectsFromToday() {
        let late = task(due: d(9, 10))
        #expect(TaskOccurrence.of(late, on: d(9, 23), today: today, calendar: cal) == .projected)
        #expect(TaskOccurrence.of(late, on: d(9, 30), today: today, calendar: cal) == .projected)
        #expect(TaskOccurrence.of(late, on: d(9, 17), today: today, calendar: cal) == nil)
    }

    @Test("projected on exact interval multiples after the due date")
    func projected() {
        let t = task(due: d(9, 17))
        #expect(TaskOccurrence.of(t, on: d(9, 24), today: today, calendar: cal) == .projected)
        #expect(TaskOccurrence.of(t, on: d(10, 1), today: today, calendar: cal) == .projected)
        #expect(TaskOccurrence.of(t, on: d(9, 23), today: today, calendar: cal) == nil)
    }

    @Test("no projection when interval is not positive")
    func zeroInterval() {
        #expect(TaskOccurrence.of(task(due: d(9, 17), every: 0), on: d(9, 24), today: today, calendar: cal) == nil)
    }

    @Test("nothing before the due date")
    func beforeDue() {
        #expect(TaskOccurrence.of(task(due: d(9, 20)), on: d(9, 18), today: today, calendar: cal) == nil)
    }

    @Test("nothing on past days, even the due day")
    func pastDay() {
        #expect(TaskOccurrence.of(task(due: d(9, 15)), on: d(9, 15), today: today, calendar: cal) == nil)
    }

    @Test("projection survives the DST change (Europe/Madrid, 28 March 2027)")
    func dst() {
        let dstToday = AgendaFixtures.date(2027, 3, 24)
        let weekly = task(due: AgendaFixtures.date(2027, 3, 25, 10))
        #expect(TaskOccurrence.of(weekly, on: AgendaFixtures.date(2027, 4, 1), today: dstToday, calendar: cal) == .projected)
        #expect(TaskOccurrence.of(weekly, on: AgendaFixtures.date(2027, 3, 31), today: dstToday, calendar: cal) == nil)
        let daily = task(due: AgendaFixtures.date(2027, 3, 27), every: 1)
        #expect(TaskOccurrence.of(daily, on: AgendaFixtures.date(2027, 3, 28), today: dstToday, calendar: cal) == .projected)
        #expect(TaskOccurrence.of(daily, on: AgendaFixtures.date(2027, 3, 29), today: dstToday, calendar: cal) == .projected)
    }
}
