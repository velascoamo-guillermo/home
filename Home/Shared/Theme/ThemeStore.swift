import SwiftUI

@Observable final class ThemeStore {
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    var colorScheme: ColorScheme? { appearance.colorScheme }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Keys.appearance)
        self.appearance = stored.flatMap(AppAppearance.init(rawValue:)) ?? .system
    }

    private enum Keys {
        static let appearance = "theme.appearance"
    }
}
