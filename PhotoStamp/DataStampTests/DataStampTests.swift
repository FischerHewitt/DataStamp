import XCTest
@testable import DataStamp

// DataStampTests — unit and integration test target for DataStamp.
// Tests are added in subsequent tasks. This file is a placeholder to
// satisfy the Xcode build system requirement that every target contains
// at least one source file.
final class DataStampTestsPlaceholder: XCTestCase {}

final class ContentViewLocationDisplayTests: XCTestCase {

    func testTargetLocationLabelUsesSavedPlaceNameWhenPresent() {
        XCTAssertEqual(
            ContentView.targetLocationLabel(
                hasLocation: true,
                label: "San Luis Obispo",
                latitude: 35.2828,
                longitude: -120.6596
            ),
            "San Luis Obispo"
        )
    }

    func testTargetLocationLabelFallsBackToCoordinatesWhenNameIsEmpty() {
        XCTAssertEqual(
            ContentView.targetLocationLabel(
                hasLocation: true,
                label: "  ",
                latitude: 35.2828,
                longitude: -120.6596
            ),
            "35.2828, -120.6596"
        )
    }

    func testTargetLocationLabelIsNilWhenNoLocationIsSelected() {
        XCTAssertNil(
            ContentView.targetLocationLabel(
                hasLocation: false,
                label: "San Luis Obispo",
                latitude: 35.2828,
                longitude: -120.6596
            )
        )
    }
}

final class PrivacyManifestTests: XCTestCase {

    func testPrivacyManifestIsBundledAndDeclaresNoTracking() throws {
        let manifest = try loadPrivacyManifest()

        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0)
    }

    func testPrivacyManifestDeclaresRequiredReasonAPIs() throws {
        let manifest = try loadPrivacyManifest()
        let accessedAPIs = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])

        XCTAssertTrue(
            accessedAPIs.containsReason(apiType: "NSPrivacyAccessedAPICategoryUserDefaults", reason: "CA92.1"),
            "UserDefaults is used for app-only preferences and must declare reason CA92.1"
        )
        XCTAssertTrue(
            accessedAPIs.containsReason(apiType: "NSPrivacyAccessedAPICategoryFileTimestamp", reason: "3B52.1"),
            "File metadata is read from user-selected files and must declare reason 3B52.1"
        )
    }

    private func loadPrivacyManifest() throws -> [String: Any] {
        let bundles = [
            Bundle.main,
            Bundle(identifier: "com.fischerhewitt.imagestampapp")
        ].compactMap { $0 }

        let manifestURL = try XCTUnwrap(
            bundles.compactMap { $0.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") }.first,
            "PrivacyInfo.xcprivacy should be present in the app bundle resources"
        )
        let data = try Data(contentsOf: manifestURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }
}

private extension Array where Element == [String: Any] {
    func containsReason(apiType: String, reason: String) -> Bool {
        contains { entry in
            entry["NSPrivacyAccessedAPIType"] as? String == apiType &&
            (entry["NSPrivacyAccessedAPITypeReasons"] as? [String])?.contains(reason) == true
        }
    }
}
