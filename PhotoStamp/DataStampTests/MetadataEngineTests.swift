import XCTest
import ImageIO
import CoreGraphics
@testable import DataStamp

// Feature: photostamp-test-suite
// Validates: Requirements 1.1, 1.2, 1.3, 1.4

/// Integration tests for MetadataEngine image date writing.
/// Each test copies a fixture to a unique UUID temp path and cleans up via addTeardownBlock.
final class MetadataEngineTests: XCTestCase {

    // MARK: - Setup / Teardown

    /// Temp copy of sample.jpg used by tests that need a mutable JPEG with EXIF.
    var tmpJPEG: URL!

    override func setUpWithError() throws {
        let bundle = Bundle(for: MetadataEngineTests.self)
        let fixture = try XCTUnwrap(
            bundle.url(forResource: "sample", withExtension: "jpg"),
            "sample.jpg fixture not found in test bundle"
        )
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try FileManager.default.copyItem(at: fixture, to: tmp)
        tmpJPEG = tmp
        addTeardownBlock { [weak self] in
            guard let url = self?.tmpJPEG else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

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

    /// Reads the EXIF dictionary from the image at `url` using CGImageSource.
    private func readExifDictionary(from url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        else { return nil }
        return exif
    }

    /// Copies a named fixture to a unique temp path and registers cleanup.
    /// Returns the temp URL.
    private func makeTempCopy(resource: String, extension ext: String) throws -> URL {
        let bundle = Bundle(for: MetadataEngineTests.self)
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

    // MARK: - Requirement 1.1: updateDate writes DateTimeOriginal, CreateDate, DateTimeDigitized

    func testUpdateDateWritesExifDateFields() throws {
        let date = makeTestDate()
        let result = MetadataEngine.updateDate(file: tmpJPEG, to: date)

        XCTAssertTrue(result.success, "updateDate should succeed on a valid JPEG: \(result.message)")

        let exif = try XCTUnwrap(
            readExifDictionary(from: tmpJPEG),
            "Could not read EXIF dictionary after updateDate"
        )

        // DateTimeOriginal
        let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        XCTAssertNotNil(dateTimeOriginal, "DateTimeOriginal should be written to EXIF")

        // DateTimeDigitized (maps to CreateDate in EXIF spec)
        let dateTimeDigitized = exif[kCGImagePropertyExifDateTimeDigitized] as? String
        XCTAssertNotNil(dateTimeDigitized, "DateTimeDigitized should be written to EXIF")

        // Verify the written value matches the expected formatted date
        let expectedDateStr = MetadataEngine.formatDate(date)
        XCTAssertEqual(dateTimeOriginal, expectedDateStr,
                       "DateTimeOriginal should equal the formatted date string")
        XCTAssertEqual(dateTimeDigitized, expectedDateStr,
                       "DateTimeDigitized should equal the formatted date string")

        // Also verify TIFF DateTime (CreateDate equivalent in TIFF dict)
        guard let source = CGImageSourceCreateWithURL(tmpJPEG as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        else {
            XCTFail("Could not read TIFF dictionary after updateDate")
            return
        }
        let tiffDateTime = tiff[kCGImagePropertyTIFFDateTime] as? String
        XCTAssertNotNil(tiffDateTime, "TIFF DateTime (CreateDate) should be written")
        XCTAssertEqual(tiffDateTime, expectedDateStr,
                       "TIFF DateTime should equal the formatted date string")
    }

    // MARK: - Requirement 1.3: updateDate on non-existent path returns success == false with non-empty message

    func testUpdateDateOnNonExistentPathFails() {
        let nonExistent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        let result = MetadataEngine.updateDate(file: nonExistent, to: makeTestDate())

        XCTAssertFalse(result.success,
                       "updateDate on a non-existent path should return success == false")
        XCTAssertFalse(result.message.isEmpty,
                       "updateDate on a non-existent path should return a non-empty message")
    }

    // MARK: - Requirement 1.2: updateDate on sample_no_exif.jpg succeeds and date round-trips

    func testUpdateDateOnNoExifJPEGSucceedsAndRoundTrips() throws {
        let tmp = try makeTempCopy(resource: "sample_no_exif", extension: "jpg")
        let date = makeTestDate()

        let result = MetadataEngine.updateDate(file: tmp, to: date)
        XCTAssertTrue(result.success,
                      "updateDate should succeed on a JPEG with no existing EXIF: \(result.message)")

        // Round-trip: read back the date and verify it's on the same calendar day
        let readBack = MetadataEngine.readCurrentDate(file: tmp)
        XCTAssertNotNil(readBack, "readCurrentDate should return a non-nil value after updateDate")

        // Parse the read-back date string (medium style: e.g. "Jun 15, 2024")
        let medFmt = DateFormatter()
        medFmt.dateStyle = .medium
        medFmt.timeStyle = .none
        if let readBackStr = readBack, let parsedDate = medFmt.date(from: readBackStr) {
            XCTAssertTrue(
                Calendar.current.isDate(parsedDate, inSameDayAs: date),
                "Round-trip date '\(readBackStr)' should be on the same calendar day as the written date"
            )
        } else {
            // Also try EXIF format directly
            let exifFmt = DateFormatter()
            exifFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let readBackStr = readBack, let parsedDate = exifFmt.date(from: readBackStr) {
                XCTAssertTrue(
                    Calendar.current.isDate(parsedDate, inSameDayAs: date),
                    "Round-trip date '\(readBackStr)' should be on the same calendar day as the written date"
                )
            } else {
                XCTFail("Could not parse read-back date string: \(readBack ?? "nil")")
            }
        }
    }

    // MARK: - Requirement 1.4: updateDate on sample.heic and sample.png succeeds

    func testUpdateDateOnHEICSucceeds() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "heic")
        let date = makeTestDate()

        let result = MetadataEngine.updateDate(file: tmp, to: date)
        XCTAssertTrue(result.success,
                      "updateDate should succeed on a HEIC file: \(result.message)")
    }

    func testUpdateDateOnPNGSucceeds() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "png")
        let date = makeTestDate()

        let result = MetadataEngine.updateDate(file: tmp, to: date)
        XCTAssertTrue(result.success,
                      "updateDate should succeed on a PNG file: \(result.message)")
    }
}
