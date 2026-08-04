import XCTest

final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsSeededFixtures() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Fixture Change Filter"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Fixture Water Plants"].exists)
        XCTAssertTrue(app.staticTexts["Fixture Filters"].exists)
    }
}
