import Foundation

// Device-level preference: deliberately off the sync/outbox path. Stores
// EXCLUDED calendars so calendars added later show up by default.
nonisolated struct CalendarSelectionStore {
    static let excludedKey = "calendar.excludedIDs.v1"
    static let bannerDismissedKey = "calendar.bannerDismissed.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: WidgetStore.appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
    }

    func excludedIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.excludedKey) ?? [])
    }

    func setExcludedIDs(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: Self.excludedKey)
    }

    var isBannerDismissed: Bool {
        defaults.bool(forKey: Self.bannerDismissedKey)
    }

    func dismissBanner() {
        defaults.set(true, forKey: Self.bannerDismissedKey)
    }
}
