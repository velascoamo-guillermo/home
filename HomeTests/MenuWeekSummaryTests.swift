import Testing
import Foundation
@testable import Casita

@Suite("MenuWeekSummary") @MainActor struct MenuWeekSummaryTests {

    private func entry(_ day: Weekday, _ slot: MealSlot, stock: Int? = nil, needed: Bool = false) -> MealEntry {
        let meal = Meal(title: "\(day.displayName) \(slot.displayName)")
        var links: [MealEntry.Link] = []
        if let stock {
            var product = StockProduct(name: "Rice", packages: 0, looseUnits: stock, unitsPerPackage: 1)
            product.needed = needed
            links = [MealEntry.Link(product: product, quantity: 2)]
        }
        return MealEntry(menuEntry: MenuEntry(dayOfWeek: day.rawValue, slot: slot, mealId: meal.id),
                         meal: meal, links: links)
    }

    @Test("empty week has no planned slots out of fourteen")
    func emptyWeek() {
        let summary = MenuWeekSummary(entries: [])
        #expect(summary.plannedCount == 0)
        #expect(MenuWeekSummary.totalSlots == 14)
        #expect(summary.shortCount == 0)
    }

    @Test("planned count and per-day slots reflect entries")
    func plannedSlots() {
        let summary = MenuWeekSummary(entries: [
            entry(.monday, .lunch), entry(.monday, .dinner), entry(.wednesday, .dinner),
        ])
        #expect(summary.plannedCount == 3)
        #expect(summary.plannedSlots(on: .monday) == [.lunch, .dinner])
        #expect(summary.plannedSlots(on: .wednesday) == [.dinner])
        #expect(summary.plannedSlots(on: .tuesday).isEmpty)
        #expect(summary.entry(day: .wednesday, slot: .dinner)?.menuEntry.dayOfWeek == 3)
        #expect(summary.entry(day: .wednesday, slot: .lunch) == nil)
    }

    @Test("short count excludes meals whose missing items are already on the shopping list")
    func shortCount() {
        let summary = MenuWeekSummary(entries: [
            entry(.monday, .lunch, stock: 0),
            entry(.tuesday, .lunch, stock: 0, needed: true),
            entry(.friday, .dinner, stock: 5),
        ])
        #expect(summary.shortCount == 1)
        #expect(summary.firstShortDay(from: .tuesday) == .monday)
    }

    @Test("first day with an empty slot searches forward from start and wraps")
    func firstEmptyDay() {
        let full = Weekday.allCases.flatMap { d in MealSlot.allCases.map { entry(d, $0) } }
        #expect(MenuWeekSummary(entries: full).firstDayWithEmptySlot(from: .monday) == nil)

        let missingTuesdayDinner = full.filter { !($0.menuEntry.dayOfWeek == 2 && $0.menuEntry.slot == .dinner) }
        let summary = MenuWeekSummary(entries: missingTuesdayDinner)
        #expect(summary.firstDayWithEmptySlot(from: .monday) == .tuesday)
        #expect(summary.firstDayWithEmptySlot(from: .tuesday) == .tuesday)
        #expect(summary.firstDayWithEmptySlot(from: .wednesday) == .tuesday)
    }

    @Test("weekday from date maps Calendar weekday to ISO Monday-first")
    func weekdayFromDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Madrid"))
        // 2026-09-14 is a Monday, 2026-09-20 a Sunday.
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 10)))
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 23)))
        #expect(Weekday(date: monday, calendar: calendar) == .monday)
        #expect(Weekday(date: sunday, calendar: calendar) == .sunday)
    }

    @Test("weekday initials follow Spanish convention with X for miércoles")
    func initials() {
        #expect(Weekday.allCases.map(\.initial) == ["L", "M", "X", "J", "V", "S", "D"])
    }

    @Test("planned chip title")
    func plannedTitle() {
        #expect(MenuWeekSummary(entries: [entry(.monday, .lunch)]).plannedTitle == "1/14 planificadas")
    }
}
