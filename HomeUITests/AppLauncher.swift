import XCTest

func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    return app
}
