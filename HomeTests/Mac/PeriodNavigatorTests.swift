#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("PeriodNavigator") @MainActor struct PeriodNavigatorTests {

    @Test("Previous/Next Period only act on Budget (Meals has no dated weeks)")
    func availability() {
        #expect(PeriodNavigator.isAvailable(on: .budget))
        for item in [SidebarItem.today, .tasks, .shopping, .stock, .meals, .pet(UUID())] {
            #expect(!PeriodNavigator.isAvailable(on: item), "\(item)")
        }
    }

    @Test("stepping crosses year boundaries both ways")
    func yearBoundaries() {
        #expect(PeriodNavigator.step(BudgetMonth(year: 2026, month: 12), by: 1) == BudgetMonth(year: 2027, month: 1))
        #expect(PeriodNavigator.step(BudgetMonth(year: 2027, month: 1), by: -1) == BudgetMonth(year: 2026, month: 12))
    }

    @Test("a multi-month step equals repeated single steps; zero is identity")
    func multiStep() {
        let nov = BudgetMonth(year: 2026, month: 11)
        #expect(PeriodNavigator.step(nov, by: 3) == BudgetMonth(year: 2027, month: 2))
        #expect(PeriodNavigator.step(nov, by: -13) == BudgetMonth(year: 2025, month: 10))
        #expect(PeriodNavigator.step(nov, by: 0) == nov)
    }
}
#endif
