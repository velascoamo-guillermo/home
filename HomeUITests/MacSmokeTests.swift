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

    /// Feature windows from `WindowGroup(for: MacWindowSeed.self)` — excludes Settings and Help.
    ///
    /// The accessibility identifier SwiftUI assigns to these windows is an implementation
    /// detail that already changed once between OS/Xcode versions: it used to start with
    /// "SwiftUI.WindowGroup", but on macOS 26.6 / Xcode 26.6 it's
    /// "SwiftUI.PresentedWindowContent<Casita.MacWindowSeed, …>-1-AppWindow-1" instead. Matching
    /// on the app's own `MacWindowSeed` content type is stable across that renaming and still
    /// excludes the Settings window (`com_apple_SwiftUI_Settings_window`) and the Help window
    /// (`Window(id: MacHelpView.windowID)`), neither of which reference that type.
    private func mainWindows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.windows.matching(NSPredicate(format: "identifier CONTAINS %@", "MacWindowSeed"))
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

    func testDeleteSelectedTaskThenUndoBringsItBack() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("2", modifierFlags: .command)
        let row = app.staticTexts["Fixture Water Plants"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", "Fixture Water Plants")).firstMatch
            .waitForExistence(timeout: 10))
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(row.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No Selection"].waitForExistence(timeout: 10))
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Fixture Water Plants"].waitForExistence(timeout: 10))
    }

    func testShoppingCheckOffAndFinish() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("3", modifierFlags: .command)
        let filters = app.checkBoxes["Fixture Filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        filters.click()
        let finish = app.buttons["finishShopping"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        finish.click()
        XCTAssertTrue(filters.waitForNonExistence(timeout: 10))
    }

    func testDeleteSelectedShoppingItemThenUndoBringsItBack() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("3", modifierFlags: .command)
        let filters = app.checkBoxes["Fixture Filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        let initialValue = filters.value as? String

        let cell = app.outlineRows.containing(.checkBox, identifier: "Fixture Filters").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).click()
        XCTAssertEqual(filters.value as? String, initialValue, "Clicking the row's trailing edge must select it, not toggle the checkbox")

        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(filters.waitForNonExistence(timeout: 10))

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
    }

    private func window(_ app: XCUIApplication, titled title: String) -> XCUIElement {
        app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch
    }

    func testDeleteSelectedStockProductThenUndoBringsItBack() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("4", modifierFlags: .command)
        let name = app.staticTexts["Fixture Milk"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))

        // Rows show up as `outlineRows` even though Stock uses a `Table`, same as List
        // (see #67); clicking the row's trailing edge selects it without hitting an
        // inner control.
        let cell = app.outlineRows.containing(.staticText, identifier: "Fixture Milk").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).click()

        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(name.waitForNonExistence(timeout: 10))

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(name.waitForExistence(timeout: 10))
    }

    func testMealsShowsTheWholeWeekAsColumns() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("5", modifierFlags: .command)
        // Day headers carry their own `mealDayHeader-<Weekday.rawValue>` identifier (added
        // instead of matching on `value BEGINSWITH <day name>`, which could also match an
        // unrelated row whose text happens to start with the same Spanish day name).
        for (day, rawValue) in [
            ("Lunes", 1), ("Martes", 2), ("Miércoles", 3), ("Jueves", 4),
            ("Viernes", 5), ("Sábado", 6), ("Domingo", 7)
        ] {
            let header = app.staticTexts["mealDayHeader-\(rawValue)"]
            XCTAssertTrue(header.waitForExistence(timeout: 10), day)
            XCTAssertTrue((header.value as? String)?.hasPrefix(day) ?? false, day)
        }
        XCTAssertTrue(app.buttons["mealSlot-7-dinner"].exists)
        app.menuBars.menuBarItems["Go"].click()
        XCTAssertFalse(app.menuBars.menuItems["Next Period"].isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testMealsCatalogKeyboardPath() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("5", modifierFlags: .command)
        let showInspector = app.toolbars.buttons["Show Inspector"]
        XCTAssertTrue(showInspector.waitForExistence(timeout: 10))
        showInspector.click()

        let name = app.staticTexts["Lentejas"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))

        // Same trailing-edge click trick as the other Mac lists: select the row without
        // triggering the row's own Button (which opens the edit sheet as the primary action).
        let cell = app.outlineRows.containing(.staticText, identifier: "Lentejas").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).click()

        // Return opens the edit sheet for the selected meal (contextMenu(forSelectionType:) primaryAction).
        app.typeKey(.enter, modifierFlags: [])
        let cancel = app.sheets.firstMatch.buttons["Cancelar"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.click()
        XCTAssertTrue(name.waitForExistence(timeout: 10))

        // ⌫ on the still-selected row opens the (non-undoable) delete confirmation; confirming removes it.
        app.typeKey(.delete, modifierFlags: [])
        let confirmDelete = app.sheets.firstMatch.buttons["Delete Meal"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 10))
        confirmDelete.click()
        XCTAssertTrue(name.waitForNonExistence(timeout: 10))
    }

    func testNextPeriodMovesBudgetToNextMonth() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("6", modifierFlags: .command)
        let title = app.staticTexts["budgetMonthTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let current = try XCTUnwrap(title.value as? String)
        XCTAssertFalse(current.isEmpty)
        // ⌘] / ⌘[ are the app's real shortcuts (unchanged for end users — verified above by
        // clicking the same menu item), but on macOS 27 a synthetic `typeKey` for the bracket
        // keys plus ⌘ no longer reaches the menu bar's key equivalent under XCUITest (it still
        // does on macOS 26.6 in CI). Driving the menu directly keeps this test meaningful and
        // OS-version-independent, matching this file's other key-equivalent workarounds.
        app.menuBars.menuBarItems["Go"].click()
        app.menuBars.menuItems["Next Period"].click()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", current), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 10), .completed)
        app.menuBars.menuBarItems["Go"].click()
        app.menuBars.menuItems["Previous Period"].click()
        XCTAssertTrue(waitForValue(title, current, timeout: 10))
    }

    func testBudgetInspectorShowsMembers() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("6", modifierFlags: .command)
        let showInspector = app.toolbars.buttons["Show Inspector"]
        XCTAssertTrue(showInspector.waitForExistence(timeout: 10))
        showInspector.click()
        XCTAssertTrue(app.buttons["Add member"].waitForExistence(timeout: 10))
    }

    func testNewPetAppearsInSidebarWithSections() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["New Pet…"].click()
        let name = app.sheets.firstMatch.textFields["petName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.click()
        name.typeText("Mishi")
        let breed = app.sheets.firstMatch.textFields["petBreed"]
        breed.click()
        breed.typeText("Tabby")
        app.sheets.firstMatch.buttons["Add"].click()
        let row = app.outlines.staticTexts["Mishi"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(window(app, titled: "Mishi").waitForExistence(timeout: 10))
        XCTAssertTrue(window(app, titled: "Mishi").radioButtons["Weight"].waitForExistence(timeout: 10))
    }

    func testImportCancelledReEnablesNewTask() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["New Pet…"].click()
        let name = app.sheets.firstMatch.textFields["petName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.click()
        name.typeText("Mishi")
        let breed = app.sheets.firstMatch.textFields["petBreed"]
        breed.click()
        breed.typeText("Tabby")
        app.sheets.firstMatch.buttons["Add"].click()
        let row = app.outlines.staticTexts["Mishi"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(window(app, titled: "Mishi").waitForExistence(timeout: 10))

        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["Import…"].click()
        let cancel = app.sheets.firstMatch.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.click()

        app.menuBars.menuBarItems["File"].click()
        XCTAssertTrue(app.menuBars.menuItems["New Task"].isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testAccessibilityAuditAcrossFeaturesLightAndDark() throws {
        for appearance in ["Light", "Dark"] {
            let app = launchApp(appearance: appearance)
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
            for shortcut in ["1", "2", "3", "4", "5", "6"] {
                app.typeKey(shortcut, modifierFlags: .command)
                XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
                try runAccessibilityAudit(on: app, appearance: appearance)
            }

            app.menuBars.menuBarItems["File"].click()
            app.menuBars.menuItems["New Pet…"].click()
            let name = app.sheets.firstMatch.textFields["petName"]
            XCTAssertTrue(name.waitForExistence(timeout: 10))
            name.click()
            name.typeText("Mishi")
            app.sheets.firstMatch.textFields["petBreed"].click()
            app.sheets.firstMatch.typeText("Tabby")
            app.sheets.firstMatch.buttons["Add"].click()
            let row = app.outlines.staticTexts["Mishi"]
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.click()
            XCTAssertTrue(window(app, titled: "Mishi").waitForExistence(timeout: 10))
            try runAccessibilityAudit(on: app, appearance: appearance)

            app.terminate()
        }
    }

    /// Toolbar glyph buttons whose 24x24pt hit region is excluded from the audit below —
    /// identified by the exact label SwiftUI's `Label` gives them, matched only against
    /// buttons that actually live in a toolbar (never a sheet/row/list button that happens
    /// to share a name).
    private static let toolbarHitRegionExclusions: Set<String> = [
        "Suggest Week", "New Expense", "Show Inspector", "Hide Inspector",
    ]

    private func runAccessibilityAudit(on app: XCUIApplication, appearance: String) throws {
        try app.performAccessibilityAudit { issue in
            // The toolbar's circular "Suggest Week" / "New Expense" / "Show Inspector"
            // glyph buttons are 24x24pt by design (matching every other Mac toolbar icon in
            // this app) — smaller than the audit's 44x44pt touch-target guidance, which is an
            // iOS/trackpad-touch rule, not a macOS pointer-driven HIG requirement. Scoped to
            // exactly those toolbar buttons (by label, and only if they're really inside a
            // toolbar) so a same-sized icon button elsewhere (sheet/row/list) is never masked.
            if issue.auditType == .hitRegion, issue.element?.elementType == .button,
               issue.element?.frame.width ?? 0 < 44, issue.element?.frame.height ?? 0 < 44,
               let label = issue.element?.label,
               Self.toolbarHitRegionExclusions.contains(label),
               app.toolbars.buttons[label].exists {
                return false
            }
            return true
        }
    }

    func testGoMenuItemTitleCaseAndDisabledNotHidden() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        app.menuBars.menuBarItems["Go"].click()
        // Title Case throughout, as shipped: no item is all-lowercase or ALL-CAPS.
        let goTitles = ["Today", "Tasks", "Shopping", "Stock", "Meals", "Budget",
                         "Previous Period", "Next Period"]
        for title in goTitles {
            let item = app.menuBars.menuItems[title]
            XCTAssertTrue(item.exists, title)
            // Exact-case lookup above already proves the title; also rule out a lowercase or
            // ALL-CAPS first word slipping back in on a future rename.
            let firstWord = title.split(separator: " ").first.map(String.init) ?? title
            XCTAssertEqual(firstWord, firstWord.prefix(1).uppercased() + firstWord.dropFirst(), title)
        }
        // Today's own window has no period to navigate: the item must stay in the menu,
        // disabled, not vanish (HIG: unavailable commands are disabled, never hidden).
        let next = app.menuBars.menuItems["Next Period"]
        XCTAssertTrue(next.exists)
        XCTAssertFalse(next.isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testTodayTaskRowContextMenuItems() throws {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        app.typeKey("1", modifierFlags: .command)
        let row = app.staticTexts["Fixture Change Filter"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.rightClick()
        for title in ["Done", "Snooze", "Section", "Add to calendar", "Delete"] {
            XCTAssertTrue(app.menuItems[title].waitForExistence(timeout: 5), title)
        }
        app.typeKey(.escape, modifierFlags: [])
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
