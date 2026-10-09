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
        XCTAssertTrue(waitForTitle(settings, "Calendars", timeout: 10))
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
        XCTAssertTrue(waitForTitle(settings, "Sync", timeout: 10))
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
        // Require the field to still exist so a vanished field can't satisfy the empty-value check.
        let cleared = NSPredicate(format: "exists == true AND (value == nil OR value == '' OR value == placeholderValue)")
        let waiter = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: cleared, object: field)], timeout: 10)
        XCTAssertEqual(waiter, .completed, "search field still holds \(String(describing: field.value))")
        XCTAssertTrue(field.exists)
        XCTAssertTrue(searchResult(app, "Fixture Milk").waitForNonExistence(timeout: 10))
        XCTAssertTrue(agendaDay.waitForExistence(timeout: 10))
    }

    func testOpenInNewWindowOpensSecondWindow() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(window(app, titled: "Tasks").waitForExistence(timeout: 10))
        XCTAssertTrue(waitForCount(mainWindows(app), 1, timeout: 10))

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

    func testReturnOnTodayTaskOpensInspectorNotSheet() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("1", modifierFlags: .command)
        let row = app.staticTexts["Fixture Change Filter"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        app.typeKey(.return, modifierFlags: [])
        let name = app.textFields.matching(NSPredicate(format: "value == %@", "Fixture Change Filter")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(app.sheets.count, 0)
    }

    func testReturnInSearchFieldWithTodayRowSelectedDoesNotOpenInspector() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("1", modifierFlags: .command)
        let row = app.staticTexts["Fixture Change Filter"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()

        app.typeKey("f", modifierFlags: .command)
        app.typeText("Fixture Milk")
        let field = app.toolbars.searchFields.firstMatch
        XCTAssertTrue(waitForValue(field, "Fixture Milk", timeout: 10))
        app.typeKey(.return, modifierFlags: [])

        XCTAssertEqual(app.sheets.count, 0)
        let name = app.textFields.matching(NSPredicate(format: "value == %@", "Fixture Change Filter")).firstMatch
        XCTAssertFalse(name.exists)
        XCTAssertTrue(waitForValue(field, "Fixture Milk", timeout: 5))
    }

    func testTypingInInspectorNameFieldIsNotInterruptedByFocusGrab() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("1", modifierFlags: .command)
        let row = app.staticTexts["Fixture Change Filter"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", "Fixture Change Filter")).firstMatch.waitForExistence(timeout: 10))
        // Re-query by position, not by value: the predicate above would stop
        // matching the instant typing changes the field's value, since
        // XCUIElement queries re-resolve lazily on every access.
        let name = app.textFields.firstMatch
        name.click()
        app.typeText(" Extra")

        let typedValue = NSPredicate(format: "value CONTAINS %@", "Extra")
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: typedValue, object: name)], timeout: 10),
            .completed, "field did not accept typed text, current value: \(String(describing: name.value))")

        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(typedValue.evaluate(with: name), "Return should not discard the just-typed text")
        XCTAssertEqual(app.sheets.count, 0)
    }

    func testArrowKeysMoveAgendaSelection() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("1", modifierFlags: .command)
        let row = app.staticTexts["Fixture Change Filter"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        app.typeKey(.return, modifierFlags: [])

        let name = app.textFields.matching(NSPredicate(format: "value == %@", "Fixture Change Filter")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10))

        app.typeKey(.downArrow, modifierFlags: [])
        let nameChanged = NSPredicate(format: "value != %@", "Fixture Change Filter")
        let waiter = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: nameChanged, object: name)], timeout: 10)
        XCTAssertEqual(waiter, .completed, "Down arrow did not move the agenda selection off the first row")
    }

    func testDeleteCommandOnSelectedTaskIsUndoable() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("1", modifierFlags: .command)
        let row = app.staticTexts["Fixture Change Filter"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()

        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(row.waitForNonExistence(timeout: 10))

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
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
