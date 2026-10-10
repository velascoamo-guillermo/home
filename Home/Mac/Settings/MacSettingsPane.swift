#if os(macOS)
enum MacSettingsPane: String, CaseIterable {
    case calendars, sync

    var title: String {
        switch self {
        case .calendars: "Calendars"
        case .sync:      "Sync"
        }
    }

    var systemImage: String {
        switch self {
        case .calendars: "calendar"
        case .sync:      "arrow.triangle.2.circlepath"
        }
    }
}
#endif
