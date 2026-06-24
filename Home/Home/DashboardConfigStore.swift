import Foundation

// Persists the dashboard layout to app-group UserDefaults. This is a local,
// device-level UI preference — it intentionally does NOT use the sync/outbox
// path. The app-group suite (shared with the widget container) lets a future
// widget read the same layout.
nonisolated struct DashboardConfigStore {
    static let key = "dashboard.config.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: WidgetStore.appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
    }

    func load() -> DashboardConfig {
        guard let data = defaults.data(forKey: Self.key),
              let config = try? JSONDecoder().decode(DashboardConfig.self, from: data)
        else { return .default }
        return config
    }

    func save(_ config: DashboardConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
