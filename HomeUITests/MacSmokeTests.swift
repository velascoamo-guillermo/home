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
        app.typeKey("f", modifierFlags: .command)
        app.typeText("Fixture Milk")
        let field = app.toolbars.searchFields.firstMatch
        XCTAssertTrue(waitForValue(field, "Fixture Milk", timeout: 10))
        XCTAssertTrue(app.staticTexts["Fixture Milk"].waitForExistence(timeout: 10))
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
