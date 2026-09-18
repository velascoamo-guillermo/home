import XCTest

final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsSeededFixtures() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Fixture Change Filter"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Fixture Standup"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["1 to buy"].exists)
        openAgendaDay(app, daysFromToday: 2)
        XCTAssertTrue(app.staticTexts["Fixture Water Plants"].waitForExistence(timeout: 10))
    }

    func testNewTaskDefaultsDueDateToOneMonth() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 15))
        openHubScreen(app, row: "Tasks")
        XCTAssertTrue(app.buttons["Add task"].waitForExistence(timeout: 10))
        app.buttons["Add task"].tap()

        let picker = app.buttons["Date Picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        let expected = formatter.string(
            from: Calendar.current.date(byAdding: .day, value: 30, to: .now)!)
        XCTAssertEqual(picker.value as? String, expected)

        let nameField = app.textFields["Name"].firstMatch
        nameField.tap()
        nameField.typeText("Fixture New Task")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Fixture New Task"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Fixture Change Filter"].waitForExistence(timeout: 10))
    }

    func testCompleteTaskFromAgenda() throws {
        // Completing a recurring task advances nextDueDate by its 7-day interval,
        // so the row leaves the day it was due on and reappears exactly one week later.
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Fixture Change Filter"].waitForExistence(timeout: 15))
        openAgendaDay(app, daysFromToday: 2)
        let done = app.buttons["markDone-Fixture Water Plants"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        XCTAssertTrue(waitForDisappearance(app.staticTexts["Fixture Water Plants"], timeout: 10))
        // Guards against a false pass: an accidentally presented edit sheet would also
        // hide the row from the day timeline behind it.
        XCTAssertFalse(app.buttons["Save"].exists)

        openAgendaDay(app, daysFromToday: 7)
        XCTAssertTrue(app.buttons["markDone-Fixture Water Plants"].waitForExistence(timeout: 10))
    }

    func testStockGaugeStepsDown() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 15))
        openHubScreen(app, row: "Stock")

        let gauge = app.descendants(matching: .any)["stockGauge-Fixture Coffee"]
        XCTAssertTrue(gauge.waitForExistence(timeout: 10))
        XCTAssertEqual(gauge.label, "Fixture Coffee, Medium")
        XCTAssertEqual(gauge.elementType, .button)

        gauge.tap()
        XCTAssertTrue(waitForLabel(gauge, "Fixture Coffee, Low", timeout: 10))
        XCTAssertFalse(app.buttons["Save"].exists)
    }

    func testStockSwipeMarksBought() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 15))
        openHubScreen(app, row: "Stock")

        let gauge = app.descendants(matching: .any)["stockGauge-Fixture Filters"]
        XCTAssertTrue(gauge.waitForExistence(timeout: 10))
        XCTAssertEqual(gauge.label, "Fixture Filters, Out")

        app.staticTexts["Fixture Filters"].firstMatch.swipeRight()
        let bought = app.buttons["Bought"]
        if bought.waitForExistence(timeout: 3) { bought.tap() }
        XCTAssertTrue(waitForLabel(gauge, "Fixture Filters, Full", timeout: 10))
    }

    func testStockChipsFilterByLevel() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 15))
        openHubScreen(app, row: "Stock")

        let outChip = app.buttons["Out 1"]
        XCTAssertTrue(outChip.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["All 3"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Low '")).firstMatch.exists)

        outChip.tap()
        XCTAssertTrue(waitForDisappearance(app.staticTexts["Fixture Milk"], timeout: 10))
        XCTAssertTrue(app.staticTexts["Fixture Filters"].exists)

        app.buttons["Out 1"].tap()
        XCTAssertTrue(app.staticTexts["Fixture Milk"].waitForExistence(timeout: 10))
    }

    func testShoppingCheckOffAndFinish() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 15))
        openHubScreen(app, row: "Shopping")

        let field = app.textFields["quickAddField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Fixture Sponge\n")

        let sponge = app.staticTexts["Fixture Sponge"].firstMatch
        XCTAssertTrue(sponge.waitForExistence(timeout: 10))
        sponge.tap()

        let finish = app.buttons["finishShopping"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        XCTAssertTrue(finish.label.contains("(1)"))
        finish.tap()
        XCTAssertTrue(waitForDisappearance(sponge, timeout: 10))
    }

    func testHeaderChipsOpenTheirOwnScreens() throws {
        // The two header Chips share one List row; a hit-testing/row-tap conflict
        // could make a single tap fire both buttons. Verify each chip opens only
        // its own screen.
        let shoppingApp = launchApp()
        let itemsToBuy = shoppingApp.buttons["1 to buy"]
        XCTAssertTrue(itemsToBuy.waitForExistence(timeout: 15))
        itemsToBuy.tap()
        XCTAssertTrue(shoppingApp.textFields["quickAddField"].waitForExistence(timeout: 10))
        XCTAssertFalse(shoppingApp.buttons["Add task"].exists)

        let tasksApp = launchApp()
        let tasksChip = tasksApp.buttons.matching(
            NSPredicate(format: "label ENDSWITH 'task' OR label ENDSWITH 'tasks'")).firstMatch
        XCTAssertTrue(tasksChip.waitForExistence(timeout: 15))
        tasksChip.tap()
        XCTAssertTrue(tasksApp.buttons["Add task"].waitForExistence(timeout: 10))
        XCTAssertFalse(tasksApp.textFields["quickAddField"].exists)
    }

    func testCompletingLinkedTaskWithoutStockShowsAlert() throws {
        let app = launchApp()
        let done = app.buttons["markDone-Fixture Change Filter"]
        XCTAssertTrue(done.waitForExistence(timeout: 15))
        done.tap()

        let alert = app.alerts["Out of stock"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts.element(
            matching: NSPredicate(format: "label CONTAINS %@", "Fixture Filters")).exists)
        XCTAssertTrue(alert.buttons["View Shopping"].exists)
        alert.buttons["OK"].tap()
        XCTAssertTrue(waitForDisappearance(alert, timeout: 10))
    }

    func testCalendarsSettingsListsFixtureCalendar() throws {
        let app = launchApp()
        openHubScreen(app, row: "Settings")
        let calendarsRow = app.buttons["Calendars"]
        XCTAssertTrue(calendarsRow.waitForExistence(timeout: 10))
        calendarsRow.tap()

        XCTAssertTrue(app.staticTexts["Fixture Work"].waitForExistence(timeout: 10))
        let toggle = app.switches["Fixture Work"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "1")

        // Prove the toggle actually wires into the agenda, not just its own list.
        // The row's accessibility frame spans the whole list row, but only the switch
        // glyph itself is hittable (same as the stock iOS Settings toggle rows), so
        // tap a point inside the switch rather than the element's reported center.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(waitForValue(toggle, "0", timeout: 10))
        app.buttons["Home"].tap()
        XCTAssertTrue(waitForDisappearance(app.staticTexts["Fixture Standup"], timeout: 10))
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func openAgendaDay(_ app: XCUIApplication, daysFromToday offset: Int) {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        let cell = app.buttons[String(format: "agendaDay-%04d-%02d-%02d", c.year!, c.month!, c.day!)]
        if !cell.waitForExistence(timeout: 5) {
            // The strip may currently show a non-current week (e.g. a prior call already
            // selected a day in a later week); re-anchor on today before walking forward
            // so a fixed, bounded number of "Next week" taps always reaches the target.
            let today = app.buttons["Today"]
            if today.exists { today.tap() }
        }
        var attempts = 0
        while !cell.waitForExistence(timeout: 5), attempts < 2 {
            app.buttons["Next week"].tap()
            attempts += 1
        }
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()
    }
}
