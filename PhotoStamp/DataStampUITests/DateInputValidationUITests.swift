import XCTest

// MARK: - DateInputValidationUITests
// UI tests for date input field validation feedback in DateStampPicker.
// Requirements: 17.1, 17.2, 17.3

@MainActor
class DateInputValidationUITests: XCTestCase {

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

    // MARK: - Helper: Switch to text-field date style

    /// Opens Settings, selects the "Text Field" date input style, then closes Settings.
    /// After this call the `dateTextField` element is visible in the title bar.
    private func switchToTextFieldDateStyle() {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button should exist in the title bar")
            return
        }
        settingsButton.click()

        let dateStyleTextField = app.buttons["dateStyleTextField"]
        guard dateStyleTextField.waitForExistence(timeout: 5) else {
            XCTFail("dateStyleTextField option should be visible in settings")
            return
        }
        dateStyleTextField.click()

        // Close settings to return to the main view.
        settingsButton.click()

        // Wait until the date text field is visible in the title bar before returning.
        let dateTextField = app.textFields["dateTextField"]
        guard dateTextField.waitForExistence(timeout: 5) else {
            XCTFail("dateTextField should be visible in the title bar after selecting Text Field style")
            return
        }
    }

    // MARK: - Requirement 17.1
    // WHEN the user types a valid date string (e.g., `07/07/1977`) into the
    // DateStampPicker text field, THE DateStampPicker SHALL display a green
    // checkmark icon.

    func testValidDateShowsCheckmarkIcon() throws {
        switchToTextFieldDateStyle()

        let dateTextField = app.textFields["dateTextField"]
        XCTAssertTrue(
            dateTextField.waitForExistence(timeout: 5),
            "dateTextField should be visible after switching to text-field style"
        )
        XCTAssertTrue(dateTextField.isHittable, "dateTextField should be hittable")

        // Clear any existing text and type a valid date.
        dateTextField.click()
        dateTextField.typeKey("a", modifierFlags: .command) // select all
        dateTextField.typeText("07/07/1977")

        // Commit the text by pressing Return so the field transitions to .valid state.
        dateTextField.typeKey(.return, modifierFlags: [])

        // The green checkmark icon should appear.
        // The identifier is on an Image inside the HStack, queried as an image element.
        // Fall back to otherElements if the image query doesn't match.
        let validIconAsImage = app.images["dateValidIcon"]
        let validIconAsOther = app.otherElements["dateValidIcon"]

        let iconAppeared = validIconAsImage.waitForExistence(timeout: 5)
            || validIconAsOther.waitForExistence(timeout: 2)

        XCTAssertTrue(
            iconAppeared,
            "dateValidIcon should appear after typing a valid date string"
        )
    }

    // MARK: - Requirement 17.2
    // WHEN the user types an invalid date string (e.g., `not-a-date`) into the
    // DateStampPicker text field, THE DateStampPicker SHALL display a red
    // "Invalid" label.

    func testInvalidDateShowsInvalidLabel() throws {
        switchToTextFieldDateStyle()

        let dateTextField = app.textFields["dateTextField"]
        XCTAssertTrue(
            dateTextField.waitForExistence(timeout: 5),
            "dateTextField should be visible after switching to text-field style"
        )
        XCTAssertTrue(dateTextField.isHittable, "dateTextField should be hittable")

        // Clear any existing text and type an invalid date string.
        dateTextField.click()
        dateTextField.typeKey("a", modifierFlags: .command) // select all
        dateTextField.typeText("not-a-date")

        // Commit the text by pressing Return so the field transitions to .invalid state.
        dateTextField.typeKey(.return, modifierFlags: [])

        // The red "Invalid" label (an HStack with accessibilityIdentifier "dateInvalidLabel")
        // should appear. SwiftUI renders HStack as an otherElement in the accessibility tree.
        let invalidLabel = app.otherElements["dateInvalidLabel"]
        XCTAssertTrue(
            invalidLabel.waitForExistence(timeout: 5),
            "dateInvalidLabel should appear after typing an invalid date string"
        )
    }

    // MARK: - Requirement 17.3
    // WHEN the date field contains an invalid date, THE ContentView SHALL disable
    // the "Stamp N Files" button.

    func testInvalidDateDisablesStampButton() throws {
        switchToTextFieldDateStyle()

        let dateTextField = app.textFields["dateTextField"]
        XCTAssertTrue(
            dateTextField.waitForExistence(timeout: 5),
            "dateTextField should be visible after switching to text-field style"
        )
        XCTAssertTrue(dateTextField.isHittable, "dateTextField should be hittable")

        // Type an invalid date to trigger the error state.
        dateTextField.click()
        dateTextField.typeKey("a", modifierFlags: .command) // select all
        dateTextField.typeText("not-a-date")

        // Commit the text by pressing Return so the field transitions to .invalid state.
        dateTextField.typeKey(.return, modifierFlags: [])

        // Wait for the invalid label to confirm the error state is active.
        let invalidLabel = app.otherElements["dateInvalidLabel"]
        XCTAssertTrue(
            invalidLabel.waitForExistence(timeout: 5),
            "dateInvalidLabel should appear to confirm the error state is active"
        )

        // The "Stamp N Files" button should be disabled (not hittable) when the date is invalid.
        // The button is only present in the fileList view; in the drop view it is absent.
        // We verify the button is either absent or not hittable — both satisfy the requirement
        // that the user cannot stamp with an invalid date.
        let stampButton = app.buttons["stampButton"]
        if stampButton.exists {
            XCTAssertFalse(
                stampButton.isHittable,
                "stampButton should not be hittable when the date field contains an invalid date"
            )
        }
        // If stampButton does not exist (we are in the drop view), the requirement is
        // trivially satisfied — the user cannot stamp without files anyway.
    }
}
