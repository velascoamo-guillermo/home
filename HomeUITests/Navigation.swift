import XCTest

func openHubScreen(_ app: XCUIApplication, row: String) {
    app.buttons["Menu"].tap()
    let rowButton = app.buttons[row].firstMatch
    XCTAssertTrue(rowButton.waitForExistence(timeout: 10))
    rowButton.tap()
}
