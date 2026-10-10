#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("MacTodayView commands") @MainActor struct MacTodayViewTests {
    private let task = HouseholdTask(title: "Water plants", intervalDays: 7, nextDueDate: .now)
    private let pet = Pet(name: "Luna", type: "Dog", breed: "Lab")

    @Test("a due or overdue task offers Mark as Done and Snooze One Day")
    func dueTask() {
        #expect(MacTodayView.commands(for: .task(task, .real)) == [.markDone, .snoozeOneDay])
        #expect(MacTodayView.commands(for: .task(task, .overdue(days: 2))) == [.markDone, .snoozeOneDay])
    }

    @Test("a projected repeat or nothing selected offers nothing")
    func nothing() {
        #expect(MacTodayView.commands(for: .task(task, .projected)).isEmpty)
        #expect(MacTodayView.commands(for: nil).isEmpty)
    }

    @Test("a non-task item, such as an appointment, offers nothing")
    func nonTask() {
        let appointment = Appointment(petId: pet.id, date: .now, reason: "Checkup", notes: "", status: .upcoming)
        #expect(MacTodayView.commands(for: .appointment(appointment, pet)).isEmpty)
    }

    @Test("⌫ deletes a real or overdue task occurrence but does nothing on a projected one")
    func deletableTask() {
        #expect(MacTodayView.deletableTask(for: .task(task, .real)) == task)
        #expect(MacTodayView.deletableTask(for: .task(task, .overdue(days: 2))) == task)
        #expect(MacTodayView.deletableTask(for: .task(task, .projected)) == nil)
        #expect(MacTodayView.deletableTask(for: nil) == nil)
    }
}
#endif
