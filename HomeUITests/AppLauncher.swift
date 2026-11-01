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
        // The Mac app follows the system appearance, which `-AppleInterfaceStyle` doesn't reliably change
        // under XCUITest, so `UITestSupport.forcedColorScheme` reads `-uitest.appearance` instead.
        app.launchArguments += ["-AppleInterfaceStyle", appearance, "-uitest.appearance", appearance.lowercased()]
    }
    #endif
    app.launch()
    return app
}
