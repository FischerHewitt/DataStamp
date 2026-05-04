import XCTest
@testable import DataStamp

// Feature: photostamp-test-suite
// Validates: Requirements 7.1, 7.2, 7.3, 7.4

/// Integration tests for MetadataEngine file-rename behaviour.
/// Each test copies a fixture to a unique UUID temp path and cleans up via addTeardownBlock.
final class MetadataEngineRenameTests: XCTestCase {

    // MARK: - Setup / Teardown

    /// Temp copy of sample.jpg used by tests that need a mutable JPEG.
    var tmpJPEG: URL!

    override func setUpWithError() throws {
        let bundle = Bundle(for: MetadataEngineRenameTests.self)
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

    /// Copies a named fixture to a unique temp path and registers cleanup.
    private func makeTempCopy(resource: String, extension ext: String) throws -> URL {
        let bundle = Bundle(for: MetadataEngineRenameTests.self)
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

    // MARK: - Requirement 7.1: Renamed file follows <prepend><yyyy-MM-dd>_<NNN><append>.<ext> pattern

    func testRenamedFileFollowsExpectedPattern() throws {
        let date = makeTestDate()
        let result = MetadataEngine.updateDate(
            file: tmpJPEG,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "pre_",
            renameAppend: "_suf"
        )

        XCTAssertTrue(result.success, "updateDate should succeed: \(result.message)")

        let renamedURL = try XCTUnwrap(result.renamedURL, "renamedURL should not be nil when rename: true")
        let filename = renamedURL.lastPathComponent

        // Register cleanup for the renamed file
        addTeardownBlock { try? FileManager.default.removeItem(at: renamedURL) }

        let pattern = #"^pre_\d{4}-\d{2}-\d{2}_001_suf\.jpg$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(filename.startIndex..., in: filename)
        let matched = regex.firstMatch(in: filename, range: range) != nil

        XCTAssertTrue(
            matched,
            "Renamed filename '\(filename)' should match pattern '\(pattern)'"
        )
    }

    // MARK: - Requirement 7.2: Path-separator characters in prepend/append are stripped

    func testInvalidCharsInPrependAppendAreStripped() throws {
        let date = makeTestDate()
        let result = MetadataEngine.updateDate(
            file: tmpJPEG,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "a/b\\c:d",
            renameAppend: "x/y\\z:w"
        )

        XCTAssertTrue(result.success, "updateDate should succeed: \(result.message)")

        let renamedURL = try XCTUnwrap(result.renamedURL, "renamedURL should not be nil when rename: true")
        let filename = renamedURL.lastPathComponent

        // Register cleanup for the renamed file
        addTeardownBlock { try? FileManager.default.removeItem(at: renamedURL) }

        XCTAssertFalse(filename.contains("/"),  "Filename should not contain '/'")
        XCTAssertFalse(filename.contains("\\"), "Filename should not contain '\\'")
        XCTAssertFalse(filename.contains(":"),  "Filename should not contain ':'")
        XCTAssertFalse(filename.contains("\0"), "Filename should not contain null character")
    }

    // MARK: - Requirement 7.3: Numeric suffix appended when target filename already exists

    func testConflictResolutionWhenTargetAlreadyExists() throws {
        let date = makeTestDate()

        // Compute the expected target filename that updateDate would produce
        let datePart = MetadataEngine.formatDateForFilename(date)
        let seq = String(format: "%03d", 1)
        let expectedName = "\(datePart)_\(seq).jpg"

        // Pre-create the expected target in the same directory as tmpJPEG
        let dir = tmpJPEG.deletingLastPathComponent()
        let preExistingURL = dir.appendingPathComponent(expectedName)
        FileManager.default.createFile(atPath: preExistingURL.path, contents: Data(), attributes: nil)
        addTeardownBlock { try? FileManager.default.removeItem(at: preExistingURL) }

        let result = MetadataEngine.updateDate(
            file: tmpJPEG,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: ""
        )

        XCTAssertTrue(result.success, "updateDate should succeed: \(result.message)")

        let renamedURL = try XCTUnwrap(result.renamedURL, "renamedURL should not be nil when rename: true")
        addTeardownBlock { try? FileManager.default.removeItem(at: renamedURL) }

        // The renamed file must have a different name than the pre-existing file
        XCTAssertNotEqual(
            renamedURL.lastPathComponent,
            expectedName,
            "Conflict resolution should produce a different filename than the pre-existing '\(expectedName)'"
        )

        // The pre-existing file must still exist
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: preExistingURL.path),
            "Pre-existing file '\(expectedName)' should still exist after conflict resolution"
        )
    }

    // MARK: - Requirement 7.4: rename: false leaves the filename unchanged

    func testRenameFalseDoesNotRenameFile() throws {
        let originalName = tmpJPEG.lastPathComponent
        let date = makeTestDate()

        let result = MetadataEngine.updateDate(
            file: tmpJPEG,
            to: date,
            rename: false
        )

        XCTAssertTrue(result.success, "updateDate should succeed: \(result.message)")
        XCTAssertNil(result.renamedURL, "renamedURL should be nil when rename: false")

        // The file should still exist at its original path
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tmpJPEG.path),
            "Original file should still exist at its original path"
        )
        XCTAssertEqual(
            tmpJPEG.lastPathComponent,
            originalName,
            "Original filename should be unchanged when rename: false"
        )
    }
}
