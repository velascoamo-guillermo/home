#if os(macOS)
import Foundation

enum PeriodNavigator {
    /// Meals is a repeating week template (`menu_entries.day_of_week`), so it has no period to step.
    static func isAvailable(on item: SidebarItem) -> Bool { item == .budget }

    static func step(_ month: BudgetMonth, by delta: Int) -> BudgetMonth {
        var result = month
        for _ in 0..<abs(delta) { result = delta > 0 ? result.next : result.previous }
        return result
    }
}
#endif
