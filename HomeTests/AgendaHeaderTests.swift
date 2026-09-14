import Testing
import Foundation
@testable import Casita

@Suite("AgendaHeaderView logic") @MainActor struct AgendaHeaderTests {

    @Test("greeting follows the hour of day")
    func greeting() {
        #expect(AgendaHeaderView.greeting(hour: 0) == "Good morning")
        #expect(AgendaHeaderView.greeting(hour: 11) == "Good morning")
        #expect(AgendaHeaderView.greeting(hour: 12) == "Good afternoon")
        #expect(AgendaHeaderView.greeting(hour: 17) == "Good afternoon")
        #expect(AgendaHeaderView.greeting(hour: 18) == "Good evening")
        #expect(AgendaHeaderView.greeting(hour: 23) == "Good evening")
    }

    @Test("title prefixes the greeting before the date")
    func title() {
        #expect(AgendaHeaderView.title(hour: 9, date: AgendaFixtures.today).hasPrefix("Good morning · "))
    }

    @Test("task chip singularizes one task")
    func taskChip() {
        #expect(AgendaHeaderView.taskChipTitle(0) == "0 tasks")
        #expect(AgendaHeaderView.taskChipTitle(1) == "1 task")
        #expect(AgendaHeaderView.taskChipTitle(3) == "3 tasks")
    }

    @Test("tasks due counts today and overdue, not future")
    func tasksDue() {
        let cal = AgendaFixtures.calendar
        let tasks = [
            HouseholdTask(title: "Late", intervalDays: 7, nextDueDate: AgendaFixtures.date(2026, 9, 10)),
            HouseholdTask(title: "Today", intervalDays: 7, nextDueDate: AgendaFixtures.date(2026, 9, 16, 20)),
            HouseholdTask(title: "Later", intervalDays: 7, nextDueDate: AgendaFixtures.date(2026, 9, 17)),
        ]
        #expect(AgendaHeaderView.tasksDue(tasks, today: AgendaFixtures.today, calendar: cal) == 2)
    }
}
