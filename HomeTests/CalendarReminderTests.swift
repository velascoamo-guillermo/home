import Testing
import Foundation
@testable import Home

@Suite struct CalendarReminderTests {
    @Test func offsetSecondsPerCase() {
        #expect(CalendarService.ReminderOffset.atTime.relativeOffset == 0)
        #expect(CalendarService.ReminderOffset.oneHourBefore.relativeOffset == -3600)
        #expect(CalendarService.ReminderOffset.oneDayBefore.relativeOffset == -86400)
    }

    @Test func allCasesHaveLabels() {
        for offset in CalendarService.ReminderOffset.allCases {
            #expect(!offset.label.isEmpty)
        }
    }
}
