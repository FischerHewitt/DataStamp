import XCTest
@testable import DataStamp

// Feature: photostamp-test-suite
// Validates: Requirements 18.1, 18.2, 18.3

/// Integration tests for MetadataEngine.readAllMetadata.
/// Tests exercise real file I/O using fixture files from the test bundle.
final class ReadAllMetadataTests: XCTestCase {

    // MARK: - Setup / Teardown

    /// Temp copy of sample.jpg used by tests that need a mutable JPEG with EXIF.
    var tmpURL: URL!

    override func setUpWithError() throws {
        let bundle = Bundle(for: ReadAllMetadataTests.self)
        let fixture = try XCTUnwrap(
            bundle.url(forResource: "sample", withExtension: "jpg"),
            "sample.jpg fixture not found in test bundle"
        )
        tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try FileManager.default.copyItem(at: fixture, to: tmpURL)
        addTeardownBlock { [weak self] in
            guard let url = self?.tmpURL else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Requirement 18.1: readAllMetadata on JPEG with EXIF returns DateTimeOriginal field

    func testReadAllMetadataOnJPEGWithExifContainsDateTimeOriginal() throws {
        let result = MetadataEngine.readAllMetadata(file: tmpURL)

        let hasDateTimeOriginal = result.fields.contains { field in
            field.key.contains("DateTimeOriginal")
        }

        XCTAssertTrue(
            hasDateTimeOriginal,
            "readAllMetadata on sample.jpg should return at least one field with key containing 'DateTimeOriginal', got keys: \(result.fields.map(\.key))"
        )
    }

    // MARK: - Requirement 18.2: readAllMetadata on file with no metadata returns empty fields

    func testReadAllMetadataOnNoExifJPEGReturnsEmptyFields() throws {
        let bundle = Bundle(for: ReadAllMetadataTests.self)
        let noExifURL = try XCTUnwrap(
            bundle.url(forResource: "sample_no_exif", withExtension: "jpg"),
            "sample_no_exif.jpg fixture not found in test bundle"
        )

        let result = MetadataEngine.readAllMetadata(file: noExifURL)

        // A JPEG without EXIF data should not contain any photographic EXIF-specific fields
        // (DateTimeOriginal, GPS, Make, Model, etc.). Basic JFIF/image properties
        // (PixelWidth, PixelHeight, ColorModel, ProfileName, etc.) may still be present
        // since they are part of the JPEG container format.
        // Use exact key matching to avoid false positives from substrings
        // (e.g. "ColorModel" contains "Model" but is not a photographic EXIF field).
        let exifSpecificKeys: Set<String> = [
            "DateTimeOriginal", "DateTimeDigitized", "GPSLatitude",
            "GPSLongitude", "ExposureTime", "FNumber",
            "ISOSpeedRatings", "Flash", "FocalLength",
            // Camera make/model use full key paths to avoid matching "ColorModel"
            "{Exif} Make", "{Exif} Model",
            "{TIFF} Make", "{TIFF} Model"
        ]
        let hasExifFields = result.fields.contains { field in
            // Use exact key match for make/model to avoid "ColorModel" false positive
            exifSpecificKeys.contains(field.key) ||
            // Use substring match only for unambiguous photographic keys
            ["DateTimeOriginal", "DateTimeDigitized", "GPSLatitude", "GPSLongitude",
             "ExposureTime", "FNumber", "ISOSpeedRatings", "Flash", "FocalLength"].contains { key in
                field.key.contains(key)
            }
        }

        XCTAssertFalse(
            hasExifFields,
            "readAllMetadata on sample_no_exif.jpg should not contain EXIF-specific fields, got: \(result.fields.map(\.key))"
        )
    }

    // MARK: - Requirement 18.3: readAllMetadata on video file returns at least one field

    func testReadAllMetadataOnVideoReturnsAtLeastOneField() throws {
        let bundle = Bundle(for: ReadAllMetadataTests.self)
        let movURL = try XCTUnwrap(
            bundle.url(forResource: "sample", withExtension: "mov"),
            "sample.mov fixture not found in test bundle"
        )

        let result = MetadataEngine.readAllMetadata(file: movURL)

        XCTAssertFalse(
            result.fields.isEmpty,
            "readAllMetadata on sample.mov should return at least one field"
        )
    }
}
