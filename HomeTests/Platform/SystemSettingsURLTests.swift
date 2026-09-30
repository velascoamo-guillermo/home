import Testing
import Foundation
@testable import Casita

@Suite("SystemSettingsURL") @MainActor struct SystemSettingsURLTests {

    @Test("calendar privacy URL targets the platform's settings surface")
    func calendarPrivacy() throws {
        let url = try #require(SystemSettingsURL.calendarPrivacy)
        #if os(macOS)
        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.hasSuffix("?Privacy_Calendars"))
        #else
        #expect(url.absoluteString == "app-settings:")
        #endif
    }

    @Test("button title names the settings app people will land in")
    func buttonTitle() {
        #if os(macOS)
        #expect(SystemSettingsURL.openButtonTitle == "Open System Settings")
        #else
        #expect(SystemSettingsURL.openButtonTitle == "Open Settings")
        #endif
    }
}
