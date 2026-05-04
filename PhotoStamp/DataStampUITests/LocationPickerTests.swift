import XCTest

// MARK: - LocationPickerTests
// UI tests for the location picker sheet workflow.
// Requirements: 16.1, 16.2, 16.3

@MainActor
class LocationPickerTests: XCTestCase {

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

    // MARK: - Requirement 16.1
    // WHEN the user clicks the location pin button in the title bar,
    // THE ContentView SHALL present the LocationPickerSheet.

    func testClickingLocationButtonPresentsLocationPickerSheet() throws {
        let locationButton = app.buttons["locationButton"]
        XCTAssertTrue(
            locationButton.waitForExistence(timeout: 5),
            "Location button should exist in the title bar"
        )
        XCTAssertTrue(locationButton.isHittable, "Location button should be hittable")

        locationButton.click()

        // The "useLocationButton" is only present inside LocationPickerSheet.
        // Waiting for it to become hittable confirms the sheet was presented.
        let useLocationButton = app.buttons["useLocationButton"]
        XCTAssertTrue(
            useLocationButton.waitForExistence(timeout: 5),
            "useLocationButton should appear after the location picker sheet is presented"
        )
        XCTAssertTrue(
            useLocationButton.isHittable,
            "useLocationButton should be hittable once the location picker sheet is open"
        )

        // Dismiss the sheet to leave the app in a clean state.
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Requirement 16.2
    // WHEN the user clicks "Use This Location" in LocationPickerSheet,
    // THE SettingsStore SHALL set hasLocation to true and store the selected coordinates,
    // causing the clearLocationButton to become visible in the title bar.

    func testClickingUseLocationButtonDismissesSheetAndShowsClearButton() throws {
        let locationButton = app.buttons["locationButton"]
        XCTAssertTrue(
            locationButton.waitForExistence(timeout: 5),
            "Location button should exist in the title bar"
        )

        // The clearLocationButton should not be visible before a location is set.
        let clearLocationButton = app.buttons["clearLocationButton"]
        XCTAssertFalse(
            clearLocationButton.exists,
            "clearLocationButton should not be visible before a location is set"
        )

        // Open the location picker sheet.
        locationButton.click()

        let useLocationButton = app.buttons["useLocationButton"]
        XCTAssertTrue(
            useLocationButton.waitForExistence(timeout: 5),
            "useLocationButton should appear after opening the location picker sheet"
        )

        // Confirm the default location (San Francisco center — the sheet's default pin).
        useLocationButton.click()

        // After confirming, the sheet should be dismissed and clearLocationButton
        // should appear in the title bar, indicating hasLocation is now true.
        XCTAssertTrue(
            clearLocationButton.waitForExistence(timeout: 5),
            "clearLocationButton should be visible in the title bar after using a location"
        )
        XCTAssertTrue(
            clearLocationButton.isHittable,
            "clearLocationButton should be hittable after a location has been set"
        )

        // The location picker sheet should no longer be visible.
        let useLocationButtonAfterDismiss = app.buttons["useLocationButton"]
        let sheetStillVisible = useLocationButtonAfterDismiss.waitForExistence(timeout: 2)
        XCTAssertFalse(
            sheetStillVisible,
            "useLocationButton should not be visible after the sheet is dismissed"
        )
    }

    // MARK: - Requirement 16.3
    // WHEN hasLocation is true and the user clicks the "×" clear button,
    // THE SettingsStore SHALL set hasLocation to false,
    // causing the clearLocationButton to be hidden and the location pin icon to reset.

    func testClickingClearLocationButtonHidesItAndResetsLocationPin() throws {
        // First, set a location so that clearLocationButton becomes visible.
        let locationButton = app.buttons["locationButton"]
        XCTAssertTrue(
            locationButton.waitForExistence(timeout: 5),
            "Location button should exist in the title bar"
        )

        locationButton.click()

        let useLocationButton = app.buttons["useLocationButton"]
        XCTAssertTrue(
            useLocationButton.waitForExistence(timeout: 5),
            "useLocationButton should appear after opening the location picker sheet"
        )
        useLocationButton.click()

        let clearLocationButton = app.buttons["clearLocationButton"]
        XCTAssertTrue(
            clearLocationButton.waitForExistence(timeout: 5),
            "clearLocationButton should be visible after setting a location"
        )

        // Now click the clear button to remove the location.
        clearLocationButton.click()

        // After clearing, clearLocationButton should no longer be visible.
        let clearButtonStillVisible = clearLocationButton.waitForExistence(timeout: 3)
        XCTAssertFalse(
            clearButtonStillVisible,
            "clearLocationButton should not be visible after clearing the location"
        )

        // The location pin button should still exist (it is always shown),
        // confirming the title bar returned to its default state.
        XCTAssertTrue(
            locationButton.waitForExistence(timeout: 5),
            "locationButton should still be visible after clearing the location"
        )
        XCTAssertTrue(
            locationButton.isHittable,
            "locationButton should be hittable after the location has been cleared"
        )
    }
}
