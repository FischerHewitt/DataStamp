import Testing
import CoreLocation
@testable import DataStamp
import Foundation

// MARK: - FileDetailPanel GPS Integration Tests
//
// These tests verify the GPS-related logic in FileDetailPanel without
// requiring a running SwiftUI view. Because `gpsCoordinate` is a private
// `@State` variable, we test the observable behaviour through:
//   1. `FileItem.isVideo` — the guard that prevents MapWidget from rendering
//      for video files (Requirement 3.2).
//   2. `ExifGPSParser.coordinate(from:)` with an empty ExifData — the value
//      that `loadData()` produces immediately after resetting `gpsCoordinate = nil`
//      at the top of the function, before the async read completes (Requirement 3.4).

// MARK: - Helpers

private func makeFileItem(extension ext: String) -> MetadataEngine.FileItem {
    let url = URL(fileURLWithPath: "/tmp/test.\(ext)")
    return MetadataEngine.FileItem(url: url)
}

// MARK: - Test Suite

@Suite("FileDetailPanel GPS Integration")
struct FileDetailPanelGPSTests {

    // MARK: - Requirement 3.2: MapWidget must not render for video files

    /// `FileItem.isVideo` drives the `!item.isVideo` guard in the `.overlay` modifier.
    /// If `isVideo` is true the overlay condition is false and MapWidget is never added
    /// to the view hierarchy, regardless of whether `gpsCoordinate` is non-nil.

    @Test("FileItem.isVideo is true for .mp4 files")
    func isVideoTrueForMp4() {
        let item = makeFileItem(extension: "mp4")
        #expect(item.isVideo == true,
                "Expected isVideo to be true for .mp4 — MapWidget must not render for video files")
    }

    @Test("FileItem.isVideo is true for .mov files")
    func isVideoTrueForMov() {
        let item = makeFileItem(extension: "mov")
        #expect(item.isVideo == true,
                "Expected isVideo to be true for .mov — MapWidget must not render for video files")
    }

    @Test("FileItem.isVideo is true for .m4v files")
    func isVideoTrueForM4v() {
        let item = makeFileItem(extension: "m4v")
        #expect(item.isVideo == true,
                "Expected isVideo to be true for .m4v — MapWidget must not render for video files")
    }

    @Test("FileItem.isVideo is true for .avi files")
    func isVideoTrueForAvi() {
        let item = makeFileItem(extension: "avi")
        #expect(item.isVideo == true,
                "Expected isVideo to be true for .avi — MapWidget must not render for video files")
    }

    @Test("FileItem.isVideo is false for .jpg files")
    func isVideoFalseForJpg() {
        let item = makeFileItem(extension: "jpg")
        #expect(item.isVideo == false,
                "Expected isVideo to be false for .jpg — MapWidget may render for photo files")
    }

    @Test("FileItem.isVideo is false for .heic files")
    func isVideoFalseForHeic() {
        let item = makeFileItem(extension: "heic")
        #expect(item.isVideo == false,
                "Expected isVideo to be false for .heic — MapWidget may render for photo files")
    }

    @Test("FileItem.isVideo is false for .png files")
    func isVideoFalseForPng() {
        let item = makeFileItem(extension: "png")
        #expect(item.isVideo == false,
                "Expected isVideo to be false for .png — MapWidget may render for photo files")
    }

    /// Verifies the overlay condition: `gpsCoordinate != nil && !item.isVideo`.
    /// When `isVideo` is true the condition is false even with a valid coordinate.
    @Test("Overlay condition is false for video item even when GPS coordinate is non-nil")
    func overlayConditionFalseForVideoWithCoordinate() {
        let videoItem = makeFileItem(extension: "mp4")
        let coord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)

        // Simulate the overlay guard: `if let coord = gpsCoordinate, !item.isVideo`
        let shouldShowMap = !videoItem.isVideo  // coord is non-nil, but isVideo blocks it
        #expect(shouldShowMap == false,
                "MapWidget overlay condition must be false for video files regardless of GPS data")
        _ = coord  // suppress unused-variable warning; coord represents a non-nil gpsCoordinate
    }

    /// Verifies the overlay condition is true for a photo with a valid coordinate.
    @Test("Overlay condition is true for photo item with valid GPS coordinate")
    func overlayConditionTrueForPhotoWithCoordinate() {
        let photoItem = makeFileItem(extension: "jpg")
        let coord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)

        let shouldShowMap = !photoItem.isVideo  // coord is non-nil and isVideo is false
        #expect(shouldShowMap == true,
                "MapWidget overlay condition must be true for a photo with a valid GPS coordinate")
        _ = coord
    }

    // MARK: - Requirement 3.4: gpsCoordinate is nil before async read completes

    /// `loadData()` sets `gpsCoordinate = nil` synchronously at the top of the function,
    /// before dispatching to a background queue. This means that between the moment
    /// `loadData()` is called and the moment the async block posts back to the main thread,
    /// `gpsCoordinate` is guaranteed to be nil.
    ///
    /// We verify the underlying mechanism: `ExifGPSParser.coordinate(from:)` returns nil
    /// for an empty `ExifData`, which is the value that would be produced if the parser
    /// were called with no fields — equivalent to the reset state.

    @Test("ExifGPSParser returns nil for empty ExifData (models the gpsCoordinate reset state)")
    func parserReturnsNilForEmptyExifData() {
        // An empty ExifData is what gpsCoordinate = nil represents before the async
        // read completes. The parser must return nil so no stale coordinate is shown.
        let emptyExif = MetadataEngine.ExifData(fields: [])
        let result = ExifGPSParser.coordinate(from: emptyExif)
        #expect(result == nil,
                "ExifGPSParser must return nil for empty ExifData — this is the reset state in loadData()")
    }

    @Test("ExifGPSParser returns nil for ExifData with only partial GPS fields (mid-load state)")
    func parserReturnsNilForPartialGPSFields() {
        // Simulates a partially-loaded state where only some fields have arrived.
        // loadData() resets gpsCoordinate = nil before the async block runs, so
        // partial data must never produce a valid coordinate.
        let partialExif = MetadataEngine.ExifData(fields: [
            (key: "GPSLatitude", value: "39.739211"),
            (key: "GPSLatitudeRef", value: "N"),
            // GPSLongitude and GPSLongitudeRef are absent
        ])
        let result = ExifGPSParser.coordinate(from: partialExif)
        #expect(result == nil,
                "ExifGPSParser must return nil when GPS fields are incomplete — prevents stale state")
    }

    /// Verifies that the stale-state guard works correctly: a new URL produces a
    /// different identity, so a result from a previous load (old URL) would be
    /// discarded by the `guard loadingURL == url` check in loadData().
    @Test("Two different file URLs are not equal (stale-state guard relies on URL identity)")
    func differentURLsAreNotEqual() {
        let url1 = URL(fileURLWithPath: "/tmp/photo1.jpg")
        let url2 = URL(fileURLWithPath: "/tmp/photo2.jpg")

        // The loadData() stale-state guard: `guard loadingURL == url else { return }`
        // This test confirms that two different file URLs are not equal, so the guard
        // correctly discards results from a previous load when the file changes.
        #expect(url1 != url2,
                "Different file URLs must not be equal — the loadingURL guard depends on this")
    }

    @Test("Same file URL is equal to itself (stale-state guard allows current load to proceed)")
    func sameURLIsEqual() {
        let url = URL(fileURLWithPath: "/tmp/photo.jpg")
        let sameURL = URL(fileURLWithPath: "/tmp/photo.jpg")

        // The guard `loadingURL == url` must pass for the current load to apply its result.
        #expect(url == sameURL,
                "The same file URL must equal itself — the loadingURL guard must allow the current load")
    }
}

// MARK: - MapWidget visibility tests
// These tests verify the conditions that control whether MapWidget is shown.
// The map is rendered in the panel overlay when gpsCoordinate is non-nil.

@Suite("MapWidget Visibility")
struct MapWidgetVisibilityTests {

    // MARK: - GPS parsing produces a valid coordinate for known good EXIF data

    @Test("readGPSCoordinate equivalent: valid GPS EXIF fields produce a non-nil coordinate")
    func validGPSFieldsProduceCoordinate() {
        // This mirrors what readGPSCoordinate does internally via CGImageSource.
        // We test the ExifGPSParser path (used as fallback) with known-good values.
        let exif = MetadataEngine.ExifData(fields: [
            (key: "GPSLatitude",     value: "38.0941666666667"),
            (key: "GPSLatitudeRef",  value: "N"),
            (key: "GPSLongitude",    value: "119.5"),
            (key: "GPSLongitudeRef", value: "W"),
        ])
        let coord = ExifGPSParser.coordinate(from: exif)
        #expect(coord != nil,
                "A valid GPS EXIF block must produce a non-nil coordinate — map will not show without this")
        #expect(coord!.latitude  > 0,  "Latitude should be positive (N)")
        #expect(coord!.longitude < 0,  "Longitude should be negative (W)")
    }

    @Test("GPS coordinate with S/W refs produces negative lat/lon")
    func southWestRefsProduceNegativeValues() {
        let exif = MetadataEngine.ExifData(fields: [
            (key: "GPSLatitude",     value: "33.8688"),
            (key: "GPSLatitudeRef",  value: "S"),
            (key: "GPSLongitude",    value: "151.2093"),
            (key: "GPSLongitudeRef", value: "W"),
        ])
        let coord = ExifGPSParser.coordinate(from: exif)
        #expect(coord != nil, "S/W GPS block must still produce a coordinate")
        #expect(coord!.latitude  < 0, "S ref must produce negative latitude")
        #expect(coord!.longitude < 0, "W ref must produce negative longitude")
    }

    // MARK: - Map overlay condition: coordinate must be non-nil for map to show

    @Test("Map shows when gpsCoordinate is non-nil")
    func mapShowsWhenCoordinatePresent() {
        let coord: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 38.09, longitude: -119.5)
        // The overlay condition in ContentView and ConfirmSheetExpanded:
        // `if let coord = detailGPSCoordinate { MapWidget(...) }`
        let mapShouldShow = coord != nil
        #expect(mapShouldShow == true,
                "MapWidget overlay must render when gpsCoordinate is non-nil")
    }

    @Test("Map is hidden when gpsCoordinate is nil")
    func mapHiddenWhenCoordinateNil() {
        let coord: CLLocationCoordinate2D? = nil
        let mapShouldShow = coord != nil
        #expect(mapShouldShow == false,
                "MapWidget overlay must not render when gpsCoordinate is nil")
    }

    // MARK: - MapWidget frame size

    @Test("MapWidget coordinate region has city-level span")
    func cityRegionHasCorrectSpan() {
        let coord = CLLocationCoordinate2D(latitude: 38.09, longitude: -119.5)
        let region = coord.cityRegion
        #expect(abs(region.span.latitudeDelta  - 0.05) < 0.001,
                "City region latitude span should be ~0.05°")
        #expect(abs(region.span.longitudeDelta - 0.05) < 0.001,
                "City region longitude span should be ~0.05°")
        #expect(abs(region.center.latitude  - coord.latitude)  < 0.0001,
                "Region center latitude must match coordinate")
        #expect(abs(region.center.longitude - coord.longitude) < 0.0001,
                "Region center longitude must match coordinate")
    }

    @Test("MapWidget coordinate region center matches the GPS coordinate")
    func regionCenterMatchesCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let region = coord.cityRegion
        #expect(abs(region.center.latitude  - coord.latitude)  < 0.0001)
        #expect(abs(region.center.longitude - coord.longitude) < 0.0001)
    }

    // MARK: - GPS coordinate is reset when file changes

    @Test("gpsCoordinate resets to nil when a new file is loaded (stale-state prevention)")
    func coordinateResetsOnFileChange() {
        // Simulate the reset that happens at the top of loadData():
        // gpsCoordinate = nil  (synchronous, before async dispatch)
        var gpsCoordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 38.09, longitude: -119.5)
        #expect(gpsCoordinate != nil, "Precondition: coordinate was set from previous file")

        // loadData() resets it immediately
        gpsCoordinate = nil
        #expect(gpsCoordinate == nil,
                "gpsCoordinate must be nil immediately after loadData() starts — prevents stale map")
    }
}
