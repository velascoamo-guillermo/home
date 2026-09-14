import Testing
import Foundation
@testable import Casita

@Suite("AgendaRow accessibility") @MainActor struct AgendaRowAccessibilityTests {

    @Test("projected task announces repeats and upcoming")
    func projectedTask() {
        let task = HouseholdTask(title: "Plants", intervalDays: 7, nextDueDate: AgendaFixtures.date(2026, 9, 10))
        let item = AgendaItem.task(task, .projected)
        #expect(AgendaRow.accessibilityLabel(for: item) == "Plants, repeats, upcoming")
    }

    @Test("real task keeps its own children so the mark-done button stays reachable")
    func realTask() {
        let task = HouseholdTask(title: "Plants", intervalDays: 7, nextDueDate: AgendaFixtures.today)
        let item = AgendaItem.task(task, .real)
        #expect(AgendaRow.accessibilityLabel(for: item) == nil)
    }

    @Test("overdue task keeps its own children so the mark-done button stays reachable")
    func overdueTask() {
        let task = HouseholdTask(title: "Plants", intervalDays: 7, nextDueDate: AgendaFixtures.date(2026, 9, 10))
        let item = AgendaItem.task(task, .overdue(days: 6))
        #expect(AgendaRow.accessibilityLabel(for: item) == nil)
    }

    @Test("meal label contains the slot display name")
    func mealLabel() throws {
        let meal = Meal(title: "Pasta")
        let item = AgendaItem.meal(meal, .dinner)
        let label = try #require(AgendaRow.accessibilityLabel(for: item))
        #expect(label.contains(MealSlot.dinner.displayName))
    }

    @Test("calendar event label contains the calendar title")
    func calendarEventLabel() throws {
        let color = CalendarColor(red: 0.1, green: 0.2, blue: 0.3)
        let event = CalendarEventSnapshot(
            itemIdentifier: "evt-1", title: "Standup",
            start: AgendaFixtures.today, end: AgendaFixtures.today.addingTimeInterval(1800),
            isAllDay: false, calendarID: "cal-1", calendarTitle: "Work", calendarColor: color)
        let item = AgendaItem.calendarEvent(event, continuesFromPreviousDay: false)
        let label = try #require(AgendaRow.accessibilityLabel(for: item))
        #expect(label.contains("Work"))
    }
}
