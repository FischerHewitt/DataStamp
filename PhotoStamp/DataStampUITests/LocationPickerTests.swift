import XCTest
@testable import DataStamp

final class LocationPickerTests: XCTestCase {

    private func makeDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = UUID().uuidString
        return (suiteName, UserDefaults(suiteName: suiteName)!)
    }

    func testUsingLocationStoresCoordinatesAndLabel() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setLocation(latitude: 37.7749, longitude: -122.4194, label: "San Francisco")

        XCTAssertTrue(store.hasLocation)
        XCTAssertEqual(store.savedLocationLat, 37.7749)
        XCTAssertEqual(store.savedLocationLon, -122.4194)
        XCTAssertEqual(store.savedLocationLabel, "San Francisco")
    }

    func testClearingLocationResetsVisibleLocationState() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setLocation(latitude: 51.5074, longitude: -0.1278, label: "London")
        store.clearLocation()

        XCTAssertFalse(store.hasLocation)
        XCTAssertEqual(store.savedLocationLabel, "")
    }

    func testLocationStatePersistsAcrossStoreInstances() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let firstStore = SettingsStore(defaults: defaults)
        firstStore.setLocation(latitude: -33.8688, longitude: 151.2093, label: "Sydney")
        defaults.synchronize()

        let secondStore = SettingsStore(defaults: defaults)
        XCTAssertTrue(secondStore.hasLocation)
        XCTAssertEqual(secondStore.savedLocationLat, -33.8688)
        XCTAssertEqual(secondStore.savedLocationLon, 151.2093)
        XCTAssertEqual(secondStore.savedLocationLabel, "Sydney")
    }
}
