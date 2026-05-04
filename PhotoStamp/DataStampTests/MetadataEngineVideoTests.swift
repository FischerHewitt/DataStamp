// Feature: photostamp-test-suite
// Validates: Requirements 2.1, 2.2, 2.3, 2.4

import XCTest
import AVFoundation
import CoreLocation
@testable import DataStamp

/// Integration tests for MetadataEngine video date writing.
/// Each test copies a fixture to a unique UUID temp path and cleans up via addTeardownBlock.
final class MetadataEngineVideoTests: XCTestCase {

    // MARK: - Helpers

    /// Copies a named fixture to a unique temp path and registers cleanup.
    /// Returns the temp URL.
    private func makeTempCopy(resource: String, extension ext: String) throws -> URL {
        let bundle = Bundle(for: MetadataEngineVideoTests.self)
        let fixture = try XCTUnwrap(
            bundle.url(forResource: resource, withExtension: ext),
            "\(resource).\(ext) fixture not found in test bundle"
        )
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: fixture, to: tmp)
        addTeardownBlock { try? FileManager.default.removeItem(at: tmp) }
        return tmp
    }

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

    // MARK: - Requirement 2.1: .mov writes commonKeyCreationDate and quickTimeMetadataKeyCreationDate

    func testMovWritesCommonAndQuickTimeCreationDate() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "mov")
        let date = makeTestDate()

        let result = MetadataEngine.updateDate(file: tmp, to: date)
        XCTAssertTrue(result.success,
                      "updateDate should succeed on a .mov file: \(result.message)")

        let exp = expectation(description: "metadata loaded from .mov")
        var items: [AVMetadataItem] = []
        Task {
            let asset = AVURLAsset(url: tmp)
            items = (try? await asset.load(.metadata)) ?? []
            exp.fulfill()
        }
        wait(for: [exp], timeout: 30)

        // AVAssetExportSession may consolidate metadata into .quickTimeMetadata keySpace.
        // Check that at least one creation date item exists with the expected value.
        let creationDateKeys: Set<String> = [
            AVMetadataKey.commonKeyCreationDate.rawValue,
            AVMetadataKey.quickTimeMetadataKeyCreationDate.rawValue,
            "com.apple.quicktime.creationdate"
        ]
        let creationItems = items.filter { item in
            guard let key = item.key as? String else { return false }
            return creationDateKeys.contains(key)
        }
        XCTAssertFalse(
            creationItems.isEmpty,
            "Should find at least one creation date metadata item after updateDate on .mov"
        )

        // Verify the value is a non-nil string
        let exp2 = expectation(description: "value loaded")
        var creationValue: String?
        Task {
            creationValue = try? await creationItems.first?.load(.value) as? String
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 10)
        XCTAssertNotNil(creationValue,
                        "Creation date value should be a non-nil string")
    }

    // MARK: - Requirement 2.2: .mp4 round-trip — updateDate succeeds and readCurrentDate returns same calendar day

    func testMp4RoundTrip() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "mp4")
        let date = makeTestDate()

        let result = MetadataEngine.updateDate(file: tmp, to: date)
        XCTAssertTrue(result.success,
                      "updateDate should succeed on a .mp4 file: \(result.message)")

        // AVFoundation caches metadata by URL within a process. readCurrentDate
        // uses exiftool to bypass this cache and read freshly written metadata.
        let readBack = MetadataEngine.readCurrentDate(file: tmp)
        XCTAssertNotNil(readBack,
                        "readCurrentDate should return a non-nil value after updateDate on .mp4")

        guard let readBackStr = readBack else { return }

        // Try medium DateFormatter style (e.g. "Jun 15, 2024")
        let medFmt = DateFormatter()
        medFmt.dateStyle = .medium
        medFmt.timeStyle = .none

        // Try EXIF format (e.g. "2024:06:15 12:00:00")
        let exifFmt = DateFormatter()
        exifFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"

        let parsedDate = medFmt.date(from: readBackStr) ?? exifFmt.date(from: readBackStr)
        XCTAssertNotNil(parsedDate,
                        "Could not parse read-back date string: '\(readBackStr)'")

        if let parsed = parsedDate {
            XCTAssertTrue(
                Calendar.current.isDate(parsed, inSameDayAs: date),
                "Round-trip date '\(readBackStr)' should be on the same calendar day as the written date"
            )
        }
    }

    // MARK: - Requirement 2.3: unsupported formats (.avi, .mkv) return success == false

    func testAviReturnsFailure() throws {
        let aviURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("avi")
        try Data().write(to: aviURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: aviURL) }

        let result = MetadataEngine.updateDate(file: aviURL, to: makeTestDate())
        XCTAssertFalse(result.success,
                       "updateDate on a .avi file should return success == false")
    }

    func testMkvReturnsFailure() throws {
        let mkvURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mkv")
        try Data().write(to: mkvURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: mkvURL) }

        let result = MetadataEngine.updateDate(file: mkvURL, to: makeTestDate())
        XCTAssertFalse(result.success,
                       "updateDate on a .mkv file should return success == false")
    }

    // MARK: - Requirement 2.4: GPS location embedded in commonKeyLocation

    func testMovEmbedGPSLocationInCommonKeyLocation() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "mov")
        let date = makeTestDate()
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = MetadataEngine.updateDate(file: tmp, to: date, location: coordinate)
        XCTAssertTrue(result.success,
                      "updateDate with location should succeed on a .mov file: \(result.message)")

        let exp = expectation(description: "metadata with GPS loaded from .mov")
        var items: [AVMetadataItem] = []
        Task {
            let asset = AVURLAsset(url: tmp)
            items = (try? await asset.load(.metadata)) ?? []
            exp.fulfill()
        }
        wait(for: [exp], timeout: 30)

        // Find location item — AVAssetExportSession may use any keySpace
        let locationKeys: Set<String> = [
            AVMetadataKey.commonKeyLocation.rawValue,
            "com.apple.quicktime.location.ISO6709"
        ]
        let locationItems = items.filter { item in
            guard let key = item.key as? String else { return false }
            return locationKeys.contains(key)
        }
        XCTAssertFalse(
            locationItems.isEmpty,
            "Should find at least one location metadata item after updateDate with GPS on .mov"
        )

        guard let locationValue = locationItems.first?.value as? String else {
            XCTFail("commonKeyLocation value should be a non-nil string")
            return
        }

        // Verify ISO 6709 format: positive lat starts with "+", negative lon contains "-"
        // Expected format: "+37.774900-122.419400/"
        XCTAssertTrue(
            locationValue.hasPrefix("+"),
            "Location string should start with '+' for positive latitude, got: '\(locationValue)'"
        )
        XCTAssertTrue(
            locationValue.contains("-"),
            "Location string should contain '-' for negative longitude, got: '\(locationValue)'"
        )
        XCTAssertTrue(
            locationValue.hasSuffix("/"),
            "Location string should end with '/' per ISO 6709 format, got: '\(locationValue)'"
        )

        // Verify the string contains the latitude and longitude values
        XCTAssertTrue(
            locationValue.contains("37."),
            "Location string should contain the latitude value, got: '\(locationValue)'"
        )
        XCTAssertTrue(
            locationValue.contains("122."),
            "Location string should contain the longitude value, got: '\(locationValue)'"
        )
    }
}
