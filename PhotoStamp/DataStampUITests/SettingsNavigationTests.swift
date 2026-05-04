import XCTest
@testable import DataStamp

final class SettingsNavigationTests: XCTestCase {

    private func makeDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = UUID().uuidString
        return (suiteName, UserDefaults(suiteName: suiteName)!)
    }

    func testSettingsButtonMovesFromCurrentViewToSettings() {
        let result = ContentView.settingsToggleResult(currentView: .drop, previousView: .drop)

        XCTAssertEqual(result.currentView, .settings)
        XCTAssertEqual(result.previousView, .drop)
    }

    func testSettingsButtonDismissesBackToPreviousView() {
        let result = ContentView.settingsToggleResult(currentView: .settings, previousView: .fileList)

        XCTAssertEqual(result.currentView, .fileList)
        XCTAssertEqual(result.previousView, .fileList)
    }

    func testSelectingTextFieldStyleUpdatesSettingsStore() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.datePickerStyle = .textField

        XCTAssertEqual(store.datePickerStyle, .textField)
    }
}
