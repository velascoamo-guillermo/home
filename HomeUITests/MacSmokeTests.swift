#if os(macOS)
import XCTest

final class MacSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGoMenuSwitchesFeatures() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(window(app, titled: "Tasks").waitForExistence(timeout: 10))
        app.menuBars.menuBarItems["Go"].click()
        app.menuBars.menuItems["Stock"].click()
        XCTAssertTrue(window(app, titled: "Stock").waitForExistence(timeout: 10))
    }

    func testCommandCommaOpensSettings() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(window(app, titled: "Calendars").waitForExistence(timeout: 10))
    }

    func testNewExpenseFromToolbarUpdatesSettlement() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("6", modifierFlags: .command)
        let hero = app.descendants(matching: .any)["budgetHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertEqual(hero.label, "All square")

        app.toolbars.buttons["New Expense"].click()
        let amount = app.textFields["expenseAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10))
        amount.click()
        amount.typeText("10")
        app.sheets.firstMatch.buttons["Alquiler"].firstMatch.click()
        app.sheets.firstMatch.radioButtons["Guille"].click()
        app.sheets.firstMatch.buttons["Save"].click()

        XCTAssertTrue(waitForLabel(hero, "Lu owes Guille 5 euros", timeout: 10))
    }

    func testCommandFFocusesToolbarSearch() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        // Find… stays disabled until the first load finishes; ⌘F before that just beeps.
        XCTAssertTrue(waitForEnabled(app.menuBars.menuItems["Find…"], timeout: 10))
        app.typeKey("f", modifierFlags: .command)
        app.typeText("Fixture Milk")
        let field = app.toolbars.searchFields.firstMatch
        XCTAssertTrue(waitForValue(field, "Fixture Milk", timeout: 10))
        // Result rows are plain buttons whose label merges the row's texts ("Fixture Milk, …").
        XCTAssertTrue(searchResult(app, "Fixture Milk").waitForExistence(timeout: 10))
        XCTAssertFalse(searchResult(app, "Fixture Coffee").exists)
    }

    func testSettingsTitleFollowsPane() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        let settings = settingsWindow(app)
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertEqual(settings.title, "Calendars")
        settings.toolbars.buttons["Sync"].click()
        XCTAssertTrue(waitForTitle(settings, "Sync", timeout: 10))
    }

    func testSettingsRestoresLastPaneWithinSession() throws {
        // Cross-launch restore is deliberately defeated: UI-test mode resets the stored pane at
        // launch (UITestSupport.resetMacSettingsPane) so every test starts on Calendars.
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        let settings = settingsWindow(app)
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.toolbars.buttons["Sync"].click()
        XCTAssertTrue(waitForTitle(settings, "Sync", timeout: 10))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertEqual(settings.title, "Sync")
    }

    func testEscapeClearsSearch() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(waitForEnabled(app.menuBars.menuItems["Find…"], timeout: 10))
        let agendaDay = app.windows.firstMatch.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "agendaDay-")).firstMatch
        XCTAssertTrue(agendaDay.waitForExistence(timeout: 10))

        app.typeKey("f", modifierFlags: .command)
        app.typeText("Fixture Milk")
        let field = app.toolbars.searchFields.firstMatch
        XCTAssertTrue(waitForValue(field, "Fixture Milk", timeout: 10))
        XCTAssertTrue(searchResult(app, "Fixture Milk").waitForExistence(timeout: 10))
        XCTAssertFalse(agendaDay.exists)

        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let cleared = NSPredicate(format: "value == nil OR value == '' OR value == placeholderValue")
        let waiter = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: cleared, object: field)], timeout: 10)
        XCTAssertEqual(waiter, .completed, "search field still holds \(String(describing: field.value))")
        XCTAssertTrue(searchResult(app, "Fixture Milk").waitForNonExistence(timeout: 10))
        XCTAssertTrue(agendaDay.waitForExistence(timeout: 10))
    }

    func testOpenInNewWindowOpensSecondWindow() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(window(app, titled: "Tasks").waitForExistence(timeout: 10))
        XCTAssertEqual(mainWindows(app).count, 1)

        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["Open in New Window"].click()

        XCTAssertTrue(waitForCount(mainWindows(app), 2, timeout: 10))
        let tasksWindows = mainWindows(app).matching(NSPredicate(format: "title == %@", "Tasks"))
        XCTAssertTrue(waitForCount(tasksWindows, 2, timeout: 10))
    }

    func testNewWindowAfterClosingLastWindow() throws {
        // Reopening from the Dock icon isn't covered: XCUITest can't drive the Dock reliably.
        let app = launchApp()
        XCTAssertTrue(mainWindows(app).firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(waitForEnabled(app.menuBars.menuItems["Find…"], timeout: 10))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(waitForCount(mainWindows(app), 0, timeout: 10))

        app.menuBars.menuBarItems["File"].click()
        let newWindow = app.menuBars.menuItems["New Window"]
        XCTAssertTrue(newWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(newWindow.isEnabled)
        XCTAssertFalse(app.menuBars.menuItems["Open in New Window"].exists)
        newWindow.click()

        XCTAssertTrue(mainWindows(app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(window(app, titled: "Today").waitForExistence(timeout: 10))
    }

    /// Feature windows from the WindowGroup — excludes Settings and Help.
    private func mainWindows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "SwiftUI.WindowGroup"))
    }

    private func settingsWindow(_ app: XCUIApplication) -> XCUIElement {
        app.windows["com_apple_SwiftUI_Settings_window"]
    }

    private func waitForCount(_ query: XCUIElementQuery, _ count: Int, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForTitle(_ element: XCUIElement, _ title: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "title == %@", title), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func searchResult(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.windows.firstMatch.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func window(_ app: XCUIApplication, titled title: String) -> XCUIElement {
        app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
#endif
