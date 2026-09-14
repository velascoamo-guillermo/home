import Testing
import EventKit
@testable import Casita

@Suite("CalendarAccessState") struct CalendarAccessStateTests {

    @Test("maps EventKit authorization statuses")
    func mapping() {
        #expect(CalendarAccessState(.fullAccess) == .fullAccess)
        #expect(CalendarAccessState(.notDetermined) == .notDetermined)
        #expect(CalendarAccessState(.denied) == .denied)
        #expect(CalendarAccessState(.restricted) == .restricted)
    }

    @Test("write-only access still needs the full-access upgrade prompt")
    func writeOnly() {
        #expect(CalendarAccessState(.writeOnly) == .notDetermined)
    }
}
