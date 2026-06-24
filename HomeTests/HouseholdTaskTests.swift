import Testing
import Foundation
@testable import Home

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
}
