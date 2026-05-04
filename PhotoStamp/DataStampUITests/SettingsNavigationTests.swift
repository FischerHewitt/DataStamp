import XCTest

// MARK: - SettingsNavigationTests
// UI tests for settings panel navigation and date style selection.
// Requirements: 15.1, 15.2, 15.3

@MainActor
class SettingsNavigationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Requirement 15.1
    // WHEN the user clicks the gear icon in the title bar,
    // THE ContentView SHALL display the SettingsView.

    func testClickingSettingsButtonShowsSettingsView() throws {
        // The "dateStyleTextField" element is only present when SettingsView is shown.
        // Verify it does not exist before opening settings.
        let dateStyleTextField = app.buttons["dateStyleTextField"]
        XCTAssertFalse(
            dateStyleTextField.exists,
            "dateStyleTextField should not be visible before opening settings"
        )

        // Click the settings gear button.
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings button should exist in the title bar"
        )
        settingsButton.click()

        // After clicking, a settings-specific element should appear.
        XCTAssertTrue(
            dateStyleTextField.waitForExistence(timeout: 5),
            "dateStyleTextField should be visible after opening settings"
        )
    }

    // MARK: - Requirement 15.3
    // WHEN the user clicks the gear icon again while SettingsView is displayed,
    // THE ContentView SHALL dismiss SettingsView and return to the previous view.

    func testClickingSettingsButtonAgainDismissesSettingsView() throws {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings button should exist in the title bar"
        )

        // Open settings.
        settingsButton.click()

        let dateStyleTextField = app.buttons["dateStyleTextField"]
        XCTAssertTrue(
            dateStyleTextField.waitForExistence(timeout: 5),
            "dateStyleTextField should be visible after opening settings"
        )

        // Click the settings button again to dismiss.
        settingsButton.click()

        // After dismissal, the settings-specific element should no longer be visible.
        // waitForExistence returns false when the element does not appear within the timeout.
        let stillVisible = dateStyleTextField.waitForExistence(timeout: 3)
        XCTAssertFalse(
            stillVisible,
            "dateStyleTextField should not be visible after dismissing settings"
        )

        // The drop zone should be visible again, confirming we returned to the previous view.
        let dropZone = app.otherElements["dropZone"]
        XCTAssertTrue(
            dropZone.waitForExistence(timeout: 5),
            "Drop zone should be visible after dismissing settings"
        )
    }

    // MARK: - Requirement 15.2
    // WHEN the user selects the "Text Field" date input style in SettingsView,
    // THE SettingsStore SHALL update datePickerStyle to .textField,
    // causing the dateTextField element to become visible in the title bar.

    func testSelectingTextFieldStyleShowsDateTextField() throws {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings button should exist in the title bar"
        )

        // Open settings.
        settingsButton.click()

        // Locate and click the "Text Field" style option.
        let dateStyleTextField = app.buttons["dateStyleTextField"]
        XCTAssertTrue(
            dateStyleTextField.waitForExistence(timeout: 5),
            "dateStyleTextField option should be visible in settings"
        )
        dateStyleTextField.click()

        // Close settings to return to the main view where the date picker is shown.
        settingsButton.click()

        // After selecting the text field style and closing settings,
        // the dateTextField element should be visible in the title bar.
        let dateTextField = app.textFields["dateTextField"]
        XCTAssertTrue(
            dateTextField.waitForExistence(timeout: 5),
            "dateTextField should be visible in the title bar after selecting Text Field style"
        )
    }
}
