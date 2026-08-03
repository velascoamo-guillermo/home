import Testing
import Foundation
@testable import Casita

@Suite("HouseholdTask – helpers") @MainActor struct HouseholdTaskTests {

    @Test("snoozedByOneDay advances nextDueDate by one day")
    func snoozeAdvancesOneDay() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let task = HouseholdTask(title: "Vacuum", icon: "x",
                                 intervalDays: 7, nextDueDate: base)
        let snoozed = task.snoozedByOneDay()
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: base)
        #expect(snoozed.nextDueDate == expected)
        #expect(snoozed.id == task.id)
        #expect(snoozed.title == "Vacuum")
    }

    @Test func defaultDueDateAddsIntervalDays() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: .now)
        let due = HouseholdTask.defaultDueDate(intervalDays: 30, from: base, calendar: cal)
        #expect(due == cal.date(byAdding: .day, value: 30, to: base))
    }

    @Test func defaultDueDateHandlesWeekInterval() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: .now)
        let due = HouseholdTask.defaultDueDate(intervalDays: 7, from: base, calendar: cal)
        #expect(due == cal.date(byAdding: .day, value: 7, to: base))
    }
}
