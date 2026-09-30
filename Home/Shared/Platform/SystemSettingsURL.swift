import Foundation
#if os(iOS)
import UIKit
#endif

enum SystemSettingsURL {
    /// Where people re-enable calendar access: the app's page in Settings on iOS,
    /// System Settings ▸ Privacy & Security ▸ Calendars on macOS.
    static var calendarPrivacy: URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        #else
        URL(string: UIApplication.openSettingsURLString)
        #endif
    }

    static var openButtonTitle: String {
        #if os(macOS)
        "Open System Settings"
        #else
        "Open Settings"
        #endif
    }
}
