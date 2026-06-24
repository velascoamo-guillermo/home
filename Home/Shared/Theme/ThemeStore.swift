import SwiftUI

@Observable final class ThemeStore {
    static let defaultTintHex = "FF7333"
    static let presets = ["FF7333", "0A84FF", "30D158", "BF5AF2", "FF375F", "5AC8FA"]

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var tintHex: String {
        didSet { defaults.set(tintHex, forKey: Keys.tintHex) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    var tint: Color { Color(hex: tintHex) ?? Color(hex: Self.defaultTintHex)! }
    var colorScheme: ColorScheme? { appearance.colorScheme }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedAppearance = defaults.string(forKey: Keys.appearance)
        self.appearance = storedAppearance.flatMap(AppAppearance.init(rawValue:)) ?? .system
        self.tintHex = defaults.string(forKey: Keys.tintHex) ?? Self.defaultTintHex
    }

    private enum Keys {
        static let appearance = "theme.appearance"
        static let tintHex = "theme.tintHex"
    }
}
