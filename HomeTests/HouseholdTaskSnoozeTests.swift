import Testing
import Foundation
@testable import Casita

@Suite @MainActor struct HouseholdTaskSnoozeTests {
    private func makeTask(due: Date) -> HouseholdTask {
        HouseholdTask(title: "x", icon: "wrench", intervalDays: 7, nextDueDate: due)
    }

    @Test func snoozeAddsGivenDays() {
        let base = Calendar.current.startOfDay(for: .now)
        let task = makeTask(due: base)
        let expected = Calendar.current.date(byAdding: .day, value: 3, to: base)
        #expect(task.snoozed(byDays: 3).nextDueDate == expected)
    }

    @Test func oneDayHelperMatchesGeneric() {
        let base = Calendar.current.startOfDay(for: .now)
        let task = makeTask(due: base)
        #expect(task.snoozedByOneDay().nextDueDate == task.snoozed(byDays: 1).nextDueDate)
    }
}
