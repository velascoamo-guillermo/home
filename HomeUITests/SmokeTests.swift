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
        // so the row leaves the day it was due on.
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Fixture Change Filter"].waitForExistence(timeout: 15))
        openAgendaDay(app, daysFromToday: 2)
        let done = app.buttons["markDone-Fixture Water Plants"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        XCTAssertTrue(waitForDisappearance(app.staticTexts["Fixture Water Plants"], timeout: 10))
    }

    func testStockConsumeAndReplenish() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 15))
        openHubScreen(app, row: "Stock")

        let consume = app.buttons["Consume one Fixture Coffee"]
        XCTAssertTrue(consume.waitForExistence(timeout: 10))
        consume.tap()
        XCTAssertTrue(waitForDisappearance(consume, timeout: 10))

        let row = app.staticTexts["Fixture Coffee"].firstMatch
        XCTAssertTrue(row.exists)
        row.swipeLeft()
        let replenish = app.buttons["Replenish"]
        XCTAssertTrue(replenish.waitForExistence(timeout: 10))
        replenish.tap()
        XCTAssertTrue(app.buttons["Consume one Fixture Coffee"].waitForExistence(timeout: 10))
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

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func openAgendaDay(_ app: XCUIApplication, daysFromToday offset: Int) {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        let cell = app.buttons[String(format: "agendaDay-%04d-%02d-%02d", c.year!, c.month!, c.day!)]
        if !cell.waitForExistence(timeout: 5) {
            app.buttons["Next week"].tap()
        }
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()
    }
}
