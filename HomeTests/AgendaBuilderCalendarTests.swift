import Testing
import Foundation
@testable import Casita

@Suite("AgendaBuilder – calendar events") @MainActor struct AgendaBuilderCalendarTests {
    private let cal = AgendaFixtures.calendar
    private let today = AgendaFixtures.today
    private let luna = Pet(name: "Luna", type: "Dog", breed: "Lab")

    private func d(_ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: m, day: day, hour: h, minute: min, second: s))!
    }
    private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEventSnapshot {
        CalendarEventSnapshot(itemIdentifier: title, title: title, start: start, end: end, isAllDay: allDay,
                              calendarID: "work", calendarTitle: "Work",
                              calendarColor: CalendarColor(red: 0, green: 0, blue: 1))
    }
    private func build(_ events: [CalendarEventSnapshot], on day: Date, input: AgendaInput = AgendaInput()) -> AgendaDay {
        var input = input
        input.calendarEvents = events
        return AgendaBuilder.build(day: day, today: today, calendar: cal, input: input)
    }

    @Test("timed event starting on the day is bucketed by start time")
    func timed() {
        let standup = event("Standup", d(9, 16, 9), d(9, 16, 9, 30))
        #expect(build([standup], on: today).items(in: .morning) == [.calendarEvent(standup, continuesFromPreviousDay: false)])
    }

    @Test("overnight event shows in the evening, then as a continuation next morning")
    func overnight() {
        let party = event("Party", d(9, 15, 22), d(9, 16, 1, 30))
        #expect(build([party], on: d(9, 15)).items(in: .evening) == [.calendarEvent(party, continuesFromPreviousDay: false)])
        #expect(build([party], on: today).items(in: .morning) == [.calendarEvent(party, continuesFromPreviousDay: true)])
    }

    @Test("event ending exactly at midnight does not leak into the next day")
    func endsAtMidnight() {
        let late = event("Late", d(9, 16, 23), d(9, 17))
        #expect(build([late], on: d(9, 17)).isEmpty)
    }

    @Test("multi-day all-day event appears in All-day on every covered day")
    func multiDayAllDay() {
        let trip = event("Trip", d(9, 15), d(9, 17, 23, 59, 59), allDay: true)
        for day in [d(9, 15), d(9, 16), d(9, 17)] {
            #expect(build([trip], on: day).items(in: .allDay).map(\.title) == ["Trip"])
        }
        #expect(build([trip], on: d(9, 18)).isEmpty)
    }

    @Test("timed event covering the whole day shows in All-day as a continuation")
    func coversWholeDay() {
        let conference = event("Conf", d(9, 15, 20), d(9, 17, 8))
        #expect(build([conference], on: today).items(in: .allDay) == [.calendarEvent(conference, continuesFromPreviousDay: true)])
    }

    @Test("same-time items sort calendar before appointment; earlier times first")
    func sortWithinBucket() {
        let nine = event("Nine", d(9, 16, 9), d(9, 16, 10))
        let ten = event("Ten", d(9, 16, 10), d(9, 16, 11))
        let vet = Appointment(petId: luna.id, date: d(9, 16, 10), reason: "Vet", notes: "", status: .upcoming)
        let day = build([ten, nine], on: today, input: AgendaInput(appointments: [vet], pets: [luna]))
        #expect(day.items(in: .morning).map(\.title) == ["Nine", "Ten", "Vet"])
    }

    @Test("dot count includes calendar events")
    func dots() {
        var input = AgendaInput()
        input.calendarEvents = [event("Standup", d(9, 16, 9), d(9, 16, 9, 30))]
        #expect(AgendaBuilder.dotCount(day: today, today: today, calendar: cal, input: input) == 1)
    }
}
