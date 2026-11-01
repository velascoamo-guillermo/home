import XCTest

func launchApp(appearance: String? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    #if os(macOS)
    // AppKit reads a bare `--uitesting` as a file to open, so a launch with no restorable
    // windows gets an open-documents event and SwiftUI never creates the default window.
    // Ignoring saved state also keeps windows from an earlier run out of the next test.
    app.launchArguments += ["-NSTreatUnknownArgumentsAsOpen", "NO", "-ApplePersistenceIgnoreState", "YES"]
    if let appearance {
        // The app resolves its scheme from its own `theme.appearance` default (preferredColorScheme),
        // so the system style alone never darkens it. The argument domain overrides that default
        // for this launch only.
        app.launchArguments += ["-AppleInterfaceStyle", appearance, "-theme.appearance", appearance.lowercased()]
    }
    #endif
    app.launch()
    return app
}
