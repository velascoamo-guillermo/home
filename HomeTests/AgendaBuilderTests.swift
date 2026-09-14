import Testing
import Foundation
@testable import Casita

@Suite("AgendaBuilder – store items") @MainActor struct AgendaBuilderTests {
    private let cal = AgendaFixtures.calendar
    private let today = AgendaFixtures.today
    private let luna = Pet(name: "Luna", type: "Dog", breed: "Lab")

    private func d(_ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        AgendaFixtures.date(2026, m, day, h, min)
    }
    private func build(_ input: AgendaInput, on day: Date? = nil) -> AgendaDay {
        AgendaBuilder.build(day: day ?? today, today: today, calendar: cal, input: input)
    }
    private func appt(_ reason: String, at date: Date, status: AppointmentStatus = .upcoming) -> Appointment {
        Appointment(petId: luna.id, date: date, reason: reason, notes: "", status: status)
    }
    private func titles(_ day: AgendaDay, _ section: AgendaSection) -> [String] {
        day.items(in: section).map(\.title)
    }

    @Test("empty input yields an empty day")
    func empty() {
        #expect(build(AgendaInput()).isEmpty)
    }

    @Test("task due today goes to Anytime as a real occurrence")
    func realTask() {
        let t = HouseholdTask(title: "Litter", intervalDays: 2, nextDueDate: d(9, 16, 8))
        let day = build(AgendaInput(tasks: [t]))
        #expect(day.items(in: .anytime) == [.task(t, .real)])
    }

    @Test("overdue tasks go to Overdue, oldest first")
    func overdueOrder() {
        let recent = HouseholdTask(title: "Recent", intervalDays: 30, nextDueDate: d(9, 15))
        let old = HouseholdTask(title: "Old", intervalDays: 30, nextDueDate: d(9, 10))
        let day = build(AgendaInput(tasks: [recent, old]))
        #expect(titles(day, .overdue) == ["Old", "Recent"])
    }

    @Test("future day shows projected repeats; past day shows no tasks")
    func projectedAndPast() {
        let t = HouseholdTask(title: "Plants", intervalDays: 7, nextDueDate: d(9, 16))
        #expect(build(AgendaInput(tasks: [t]), on: d(9, 23)).items(in: .anytime) == [.task(t, .projected)])
        #expect(build(AgendaInput(tasks: [t]), on: d(9, 9)).isEmpty)
    }

    @Test("appointments bucket at 12:00 and 18:00 boundaries")
    func buckets() {
        let input = AgendaInput(
            appointments: [appt("A1159", at: d(9, 16, 11, 59)), appt("A1200", at: d(9, 16, 12)),
                           appt("A1759", at: d(9, 16, 17, 59)), appt("A1800", at: d(9, 16, 18))],
            pets: [luna])
        let day = build(input)
        #expect(titles(day, .morning) == ["A1159"])
        #expect(titles(day, .afternoon) == ["A1200", "A1759"])
        #expect(titles(day, .evening) == ["A1800"])
    }

    @Test("cancelled appointments never show; done only on past days")
    func appointmentStatus() {
        let input = AgendaInput(
            appointments: [appt("Cancelled", at: d(9, 16, 10), status: .cancelled),
                           appt("DoneToday", at: d(9, 16, 11), status: .done),
                           appt("DonePast", at: d(9, 14, 11), status: .done)],
            pets: [luna])
        #expect(build(input).isEmpty)
        #expect(titles(build(input, on: d(9, 14)), .morning) == ["DonePast"])
    }

    @Test("appointment for an unknown pet is skipped")
    func unknownPet() {
        #expect(build(AgendaInput(appointments: [appt("Orphan", at: d(9, 16, 10))])).isEmpty)
    }

    @Test("pet events go to Anytime ahead of tasks")
    func petEventsBeforeTasks() {
        let event = PetEvent(petId: luna.id, date: d(9, 16, 15), title: "Vaccine", category: .vaccine, notes: "", value: nil)
        let t = HouseholdTask(title: "A task", intervalDays: 7, nextDueDate: d(9, 16))
        let day = build(AgendaInput(tasks: [t], petEvents: [event], pets: [luna]))
        #expect(titles(day, .anytime) == ["Vaccine", "A task"])
    }

    @Test("lunch goes to Afternoon above timed items; dinner to Evening")
    func meals() {
        let lunch = Meal(title: "Salad")
        let dinner = Meal(title: "Pasta")
        let input = AgendaInput(
            appointments: [appt("Vet", at: d(9, 16, 13))],
            pets: [luna],
            menuEntries: [MenuEntry(dayOfWeek: 3, slot: .lunch, mealId: lunch.id),
                          MenuEntry(dayOfWeek: 3, slot: .dinner, mealId: dinner.id),
                          MenuEntry(dayOfWeek: 4, slot: .lunch, mealId: dinner.id)],
            meals: [lunch, dinner])
        let day = build(input)
        #expect(titles(day, .afternoon) == ["Salad", "Vet"])
        #expect(titles(day, .evening) == ["Pasta"])
    }

    @Test("duplicate slot keeps newest entry; empty or missing meals are skipped")
    func mealDedupe() {
        let old = Meal(title: "Old")
        let new = Meal(title: "New")
        let blank = Meal(title: "")
        let input = AgendaInput(
            menuEntries: [MenuEntry(dayOfWeek: 3, slot: .lunch, mealId: old.id, updatedAt: d(9, 1)),
                          MenuEntry(dayOfWeek: 3, slot: .lunch, mealId: new.id, updatedAt: d(9, 2)),
                          MenuEntry(dayOfWeek: 3, slot: .dinner, mealId: blank.id),
                          MenuEntry(dayOfWeek: 5, slot: .dinner, mealId: UUID())],
            meals: [old, new, blank])
        let day = build(input)
        #expect(titles(day, .afternoon) == ["New"])
        #expect(day.items(in: .evening).isEmpty)
    }

    @Test("ISO weekday is 1 = Monday … 7 = Sunday regardless of firstWeekday")
    func isoWeekday() {
        for c in [AgendaFixtures.makeCalendar(firstWeekday: 1), AgendaFixtures.makeCalendar(firstWeekday: 2)] {
            #expect(AgendaBuilder.isoWeekday(of: d(9, 14), calendar: c) == 1)
            #expect(AgendaBuilder.isoWeekday(of: d(9, 16), calendar: c) == 3)
            #expect(AgendaBuilder.isoWeekday(of: d(9, 20), calendar: c) == 7)
        }
    }

    @Test("groups follow section order and omit empty sections")
    func groupOrder() {
        let overdue = HouseholdTask(title: "Late", intervalDays: 30, nextDueDate: d(9, 1))
        let input = AgendaInput(tasks: [overdue], appointments: [appt("Eve", at: d(9, 16, 19))], pets: [luna])
        #expect(build(input).groups.map(\.section) == [.overdue, .evening])
    }

    @Test("dot count includes projected repeats and excludes overdue")
    func dotCount() {
        let late = HouseholdTask(title: "Late", intervalDays: 30, nextDueDate: d(9, 1))
        let daily = HouseholdTask(title: "Daily", intervalDays: 1, nextDueDate: d(9, 16))
        let input = AgendaInput(tasks: [late, daily])
        #expect(AgendaBuilder.dotCount(day: today, today: today, calendar: cal, input: input) == 1)
        #expect(AgendaBuilder.dotCount(day: d(9, 17), today: today, calendar: cal, input: input) == 1)
    }
}
