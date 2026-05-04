import XCTest
import ImageIO
import CoreGraphics
import CoreLocation
@testable import DataStamp

// Feature: photostamp-test-suite
// Validates: Requirements 3.1, 3.2, 3.3

/// Integration tests for MetadataEngine GPS coordinate embedding.
/// Each test copies a fixture to a unique UUID temp path and cleans up via addTeardownBlock.
final class MetadataEngineGPSTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a fixed test date: 2024-06-15 12:00:00 UTC.
    private func makeTestDate() -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    /// Copies `sample.jpg` to a unique temp path and registers cleanup.
    /// Returns the temp URL.
    private func makeTempJPEG() throws -> URL {
        let bundle = Bundle(for: MetadataEngineGPSTests.self)
        let fixture = try XCTUnwrap(
            bundle.url(forResource: "sample", withExtension: "jpg"),
            "sample.jpg fixture not found in test bundle"
        )
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try FileManager.default.copyItem(at: fixture, to: tmp)
        addTeardownBlock { try? FileManager.default.removeItem(at: tmp) }
        return tmp
    }

    /// Reads the GPS dictionary from the image at `url` using CGImageSource.
    private func readGPSDictionary(from url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        else { return nil }
        return gps
    }

    // MARK: - Requirement 3.1: Positive lat/lon writes "N" and "E"

    func testPositiveLatLonWritesNorthAndEast() throws {
        let tmp = try makeTempJPEG()
        let date = makeTestDate()
        let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: 122.4194)

        let result = MetadataEngine.updateDate(file: tmp, to: date, location: location)
        XCTAssertTrue(result.success,
                      "updateDate should succeed with a positive lat/lon: \(result.message)")

        let gps = try XCTUnwrap(
            readGPSDictionary(from: tmp),
            "Could not read GPS dictionary after updateDate with positive coordinates"
        )

        let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String

        XCTAssertEqual(latRef, "N",
                       "GPSLatitudeRef should be 'N' for positive latitude")
        XCTAssertEqual(lonRef, "E",
                       "GPSLongitudeRef should be 'E' for positive longitude")
    }

    // MARK: - Requirement 3.2: Negative lat/lon writes "S" and "W"

    func testNegativeLatLonWritesSouthAndWest() throws {
        let tmp = try makeTempJPEG()
        let date = makeTestDate()
        let location = CLLocationCoordinate2D(latitude: -33.8688, longitude: -70.6693)

        let result = MetadataEngine.updateDate(file: tmp, to: date, location: location)
        XCTAssertTrue(result.success,
                      "updateDate should succeed with a negative lat/lon: \(result.message)")

        let gps = try XCTUnwrap(
            readGPSDictionary(from: tmp),
            "Could not read GPS dictionary after updateDate with negative coordinates"
        )

        let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String

        XCTAssertEqual(latRef, "S",
                       "GPSLatitudeRef should be 'S' for negative latitude")
        XCTAssertEqual(lonRef, "W",
                       "GPSLongitudeRef should be 'W' for negative longitude")
    }

    // MARK: - Requirement 3.3: nil location does not modify existing GPS fields

    func testNilLocationDoesNotModifyExistingGPSFields() throws {
        let tmp = try makeTempJPEG()
        let date = makeTestDate()

        // First, write GPS data to the file so there are existing GPS fields
        let initialLocation = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        let firstResult = MetadataEngine.updateDate(file: tmp, to: date, location: initialLocation)
        XCTAssertTrue(firstResult.success,
                      "Initial updateDate with location should succeed: \(firstResult.message)")

        // Read back the GPS fields written in the first pass
        let gpsBefore = try XCTUnwrap(
            readGPSDictionary(from: tmp),
            "Could not read GPS dictionary after first updateDate"
        )
        let latRefBefore = gpsBefore[kCGImagePropertyGPSLatitudeRef] as? String
        let lonRefBefore = gpsBefore[kCGImagePropertyGPSLongitudeRef] as? String
        let latBefore = gpsBefore[kCGImagePropertyGPSLatitude] as? Double
        let lonBefore = gpsBefore[kCGImagePropertyGPSLongitude] as? Double

        // Now call updateDate with nil location — GPS fields must remain unchanged
        let secondResult = MetadataEngine.updateDate(file: tmp, to: date, location: nil)
        XCTAssertTrue(secondResult.success,
                      "updateDate with nil location should succeed: \(secondResult.message)")

        let gpsAfter = try XCTUnwrap(
            readGPSDictionary(from: tmp),
            "GPS dictionary should still be present after updateDate with nil location"
        )
        let latRefAfter = gpsAfter[kCGImagePropertyGPSLatitudeRef] as? String
        let lonRefAfter = gpsAfter[kCGImagePropertyGPSLongitudeRef] as? String
        let latAfter = gpsAfter[kCGImagePropertyGPSLatitude] as? Double
        let lonAfter = gpsAfter[kCGImagePropertyGPSLongitude] as? Double

        XCTAssertEqual(latRefAfter, latRefBefore,
                       "GPSLatitudeRef should be unchanged after updateDate with nil location")
        XCTAssertEqual(lonRefAfter, lonRefBefore,
                       "GPSLongitudeRef should be unchanged after updateDate with nil location")
        XCTAssertEqual(latAfter, latBefore,
                       "GPSLatitude should be unchanged after updateDate with nil location")
        XCTAssertEqual(lonAfter, lonBefore,
                       "GPSLongitude should be unchanged after updateDate with nil location")
    }
}
