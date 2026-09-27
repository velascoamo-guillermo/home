import Testing
import Foundation
@testable import Casita

@Suite("BudgetMonth") @MainActor struct BudgetMonthTests {
    private let cal = BudgetFixtures.calendar

    @Test("month from a mid-month date")
    func fromDate() {
        #expect(BudgetMonth(date: BudgetFixtures.date(2026, 11, 15), calendar: cal)
                == BudgetMonth(year: 2026, month: 11))
    }

    @Test("last minute of the month and first minute of the next")
    func boundaries() {
        #expect(BudgetMonth(date: BudgetFixtures.date(2026, 11, 30, 23, 59), calendar: cal)
                == BudgetMonth(year: 2026, month: 11))
        #expect(BudgetMonth(date: BudgetFixtures.date(2026, 12, 1, 0, 0), calendar: cal)
                == BudgetMonth(year: 2026, month: 12))
    }

    @Test("00:30 on the 1st local time is the new month even though UTC is still the old one")
    func localMidnightBoundary() {
        let justAfterMidnight = BudgetFixtures.date(2026, 12, 1, 0, 30)
        #expect(BudgetMonth(date: justAfterMidnight, calendar: cal) == BudgetMonth(year: 2026, month: 12))
        #expect(BudgetMonth(date: justAfterMidnight, calendar: BudgetFixtures.utcCalendar)
                == BudgetMonth(year: 2026, month: 11))
        #expect(BudgetMonth(year: 2026, month: 12).contains(justAfterMidnight, calendar: cal))
        #expect(!BudgetMonth(year: 2026, month: 11).contains(justAfterMidnight, calendar: cal))
    }

    @Test("next and previous cross the year boundary")
    func navigation() {
        #expect(BudgetMonth(year: 2026, month: 12).next == BudgetMonth(year: 2027, month: 1))
        #expect(BudgetMonth(year: 2027, month: 1).previous == BudgetMonth(year: 2026, month: 12))
        #expect(BudgetMonth(year: 2026, month: 5).next == BudgetMonth(year: 2026, month: 6))
    }

    @Test("key is zero-padded YYYY-MM and parses back")
    func key() {
        #expect(BudgetMonth(year: 2026, month: 3).key == "2026-03")
        #expect(BudgetMonth(year: 2026, month: 11).key == "2026-11")
        #expect(BudgetMonth(key: "2026-03") == BudgetMonth(year: 2026, month: 3))
        #expect(BudgetMonth(key: "2026-13") == nil)
        #expect(BudgetMonth(key: "2026-3") == nil)
        #expect(BudgetMonth(key: "nope") == nil)
    }

    @Test("ordering is chronological")
    func comparable() {
        #expect(BudgetMonth(year: 2026, month: 12) < BudgetMonth(year: 2027, month: 1))
        #expect(BudgetMonth(year: 2026, month: 2) < BudgetMonth(year: 2026, month: 10))
        #expect(!(BudgetMonth(year: 2026, month: 10) < BudgetMonth(year: 2026, month: 10)))
    }

    @Test("date(day:) is noon on that day, clamped to 1...28")
    func dayDate() {
        let m = BudgetMonth(year: 2027, month: 2)
        let d = m.date(day: 5, calendar: cal)
        #expect(cal.component(.day, from: d) == 5)
        #expect(cal.component(.hour, from: d) == 12)
        #expect(cal.component(.day, from: m.date(day: 31, calendar: cal)) == 28)
        #expect(cal.component(.day, from: m.date(day: 0, calendar: cal)) == 1)
    }

    @Test("title is the capitalised month name and year")
    func title() {
        let m = BudgetMonth(year: 2026, month: 11)
        #expect(m.title(locale: Locale(identifier: "es_ES"), calendar: cal) == "Noviembre 2026")
        #expect(m.title(locale: Locale(identifier: "en_US"), calendar: cal) == "November 2026")
    }
}
