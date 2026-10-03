#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("MacTodayView commands") @MainActor struct MacTodayViewTests {
    private let task = HouseholdTask(title: "Water plants", intervalDays: 7, nextDueDate: .now)

    @Test("a due or overdue task offers Mark as Done and Snooze One Day")
    func dueTask() {
        #expect(MacTodayView.commands(for: .task(task, .real)) == [.markDone, .snoozeOneDay])
        #expect(MacTodayView.commands(for: .task(task, .overdue(days: 2))) == [.markDone, .snoozeOneDay])
    }

    @Test("a projected repeat, nothing selected, or a non-task offers nothing")
    func nothing() {
        #expect(MacTodayView.commands(for: .task(task, .projected)).isEmpty)
        #expect(MacTodayView.commands(for: nil).isEmpty)
    }
}
#endif
