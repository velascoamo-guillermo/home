import Foundation

struct MenuWeekSummary {
    static let totalSlots = Weekday.allCases.count * MealSlot.allCases.count

    private let entries: [MealEntry]

    init(entries: [MealEntry]) {
        self.entries = entries
    }

    var plannedCount: Int { entries.count }

    /// Meals short on stock whose missing items are not yet on the shopping list.
    var shortCount: Int { entries.filter(Self.needsShopping).count }

    var plannedTitle: String { "\(plannedCount)/\(Self.totalSlots) planificadas" }

    func entry(day: Weekday, slot: MealSlot) -> MealEntry? {
        entries.first { $0.menuEntry.dayOfWeek == day.rawValue && $0.menuEntry.slot == slot }
    }

    func plannedSlots(on day: Weekday) -> Set<MealSlot> {
        Set(entries.filter { $0.menuEntry.dayOfWeek == day.rawValue }.map(\.menuEntry.slot))
    }

    func firstDayWithEmptySlot(from start: Weekday) -> Weekday? {
        Self.days(from: start).first { plannedSlots(on: $0).count < MealSlot.allCases.count }
    }

    func firstShortDay(from start: Weekday) -> Weekday? {
        Self.days(from: start).first { day in
            entries.contains { $0.menuEntry.dayOfWeek == day.rawValue && Self.needsShopping($0) }
        }
    }

    private static func needsShopping(_ entry: MealEntry) -> Bool {
        entry.isShort && !entry.allShortNeeded
    }

    private static func days(from start: Weekday) -> [Weekday] {
        let all = Weekday.allCases
        let index = start.rawValue - 1
        return Array(all[index...] + all[..<index])
    }
}
