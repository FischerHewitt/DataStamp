import XCTest
@testable import DataStamp

final class DateInputValidationTests: XCTestCase {

    func testValidDateInputResolvesToValidState() {
        XCTAssertEqual(
            dateStampFieldState(for: "07/07/1977", isFocused: false),
            .valid
        )
        XCTAssertNotNil(parseDateString("07/07/1977"))
    }

    func testInvalidDateInputResolvesToInvalidState() {
        XCTAssertEqual(
            dateStampFieldState(for: "not-a-date", isFocused: true),
            .invalid
        )
        XCTAssertNil(parseDateString("not-a-date"))
    }

    func testPartialFocusedDateInputRemainsEditing() {
        XCTAssertEqual(
            dateStampFieldState(for: "07", isFocused: true),
            .editing
        )
    }

    func testInvalidDateStateDisablesStampAction() {
        XCTAssertFalse(ContentView.isStampButtonEnabled(selectedItemCount: 1, dateHasError: true))
        XCTAssertFalse(ContentView.isStampButtonEnabled(selectedItemCount: 0, dateHasError: false))
        XCTAssertTrue(ContentView.isStampButtonEnabled(selectedItemCount: 1, dateHasError: false))
    }
}
