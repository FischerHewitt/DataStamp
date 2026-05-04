import XCTest
import ImageIO
import CoreGraphics
@testable import DataStamp

// Feature: photostamp-test-suite
// Validates: Requirements 4.1, 4.2, 4.3, 4.4

/// Integration tests for MetadataEngine backup creation and undo (restore) behaviour.
/// Each test copies a fixture to a unique UUID temp path and cleans up via addTeardownBlock.
final class MetadataEngineBackupTests: XCTestCase {

    // MARK: - Helpers

    /// Copies a named fixture to a unique temp path and registers cleanup.
    /// Returns the temp URL.
    private func makeTempCopy(resource: String, extension ext: String) throws -> URL {
        let bundle = Bundle(for: MetadataEngineBackupTests.self)
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

    /// Returns the expected backup URL for a given file URL.
    /// MetadataEngine uses `<name>.bak_<ext>` (e.g. `abc123.bak_jpg`).
    private func expectedBackupURL(for fileURL: URL) -> URL {
        let ext = fileURL.pathExtension
        return ext.isEmpty
            ? fileURL.appendingPathExtension("bak")
            : fileURL.deletingPathExtension().appendingPathExtension("bak_\(ext)")
    }

    // MARK: - Requirement 4.1: createBackup: true creates a .bak_<ext> file

    func testCreateBackupTrueCreatesBackupFile() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "jpg")
        let backupURL = expectedBackupURL(for: tmp)
        // Register cleanup for the backup file as well
        addTeardownBlock { try? FileManager.default.removeItem(at: backupURL) }

        let result = MetadataEngine.updateDate(
            file: tmp,
            to: makeTestDate(),
            createBackup: true
        )

        XCTAssertTrue(result.success,
                      "updateDate with createBackup: true should succeed: \(result.message)")
        XCTAssertNotNil(result.backupURL,
                        "FileResult.backupURL should be non-nil when createBackup is true")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: backupURL.path),
            "Backup file should exist at \(backupURL.path)"
        )
        XCTAssertEqual(
            result.backupURL?.lastPathComponent,
            backupURL.lastPathComponent,
            "FileResult.backupURL filename should match the expected .bak_jpg pattern"
        )
    }

    // MARK: - Requirement 4.4: createBackup: false does NOT create a backup file

    func testCreateBackupFalseDoesNotCreateBackupFile() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "jpg")
        let backupURL = expectedBackupURL(for: tmp)

        let result = MetadataEngine.updateDate(
            file: tmp,
            to: makeTestDate(),
            createBackup: false
        )

        XCTAssertTrue(result.success,
                      "updateDate with createBackup: false should succeed: \(result.message)")
        XCTAssertNil(result.backupURL,
                     "FileResult.backupURL should be nil when createBackup is false")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: backupURL.path),
            "No backup file should exist when createBackup is false"
        )
    }

    // MARK: - Requirement 4.2: undoStamp restores the original file and returns correct restored count

    func testUndoStampRestoresOriginalFileAndReturnsCorrectCount() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "jpg")
        let backupURL = expectedBackupURL(for: tmp)
        addTeardownBlock { try? FileManager.default.removeItem(at: backupURL) }

        // Capture the original file size before stamping so we can verify restoration
        let originalSize = try FileManager.default.attributesOfItem(atPath: tmp.path)[.size] as? Int

        let date = makeTestDate()
        let stampResult = MetadataEngine.updateDate(
            file: tmp,
            to: date,
            createBackup: true
        )
        XCTAssertTrue(stampResult.success,
                      "Stamp step should succeed before testing undo: \(stampResult.message)")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: backupURL.path),
            "Backup file must exist before calling undoStamp"
        )

        // Perform undo
        let (restored, failed) = MetadataEngine.undoStamp(results: [stampResult])

        XCTAssertEqual(restored, 1,
                       "undoStamp should report 1 restored file")
        XCTAssertEqual(failed, 0,
                       "undoStamp should report 0 failures when backup exists")

        // The backup file should have been moved back — it should no longer exist as a .bak_jpg
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: backupURL.path),
            "Backup file should be removed after a successful undo"
        )

        // The original file should exist at its original path
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tmp.path),
            "Original file should be restored at its original path after undo"
        )

        // Verify the restored file size matches the original (content was actually restored)
        let restoredSize = try FileManager.default.attributesOfItem(atPath: tmp.path)[.size] as? Int
        XCTAssertEqual(
            restoredSize, originalSize,
            "Restored file size should match the original file size"
        )
    }

    // MARK: - Requirement 4.3: undoStamp increments failed count when backup file is missing

    func testUndoStampIncrementsFailedCountWhenBackupMissing() throws {
        let tmp = try makeTempCopy(resource: "sample", extension: "jpg")
        let backupURL = expectedBackupURL(for: tmp)
        addTeardownBlock { try? FileManager.default.removeItem(at: backupURL) }

        // Stamp with backup so we get a valid FileResult with a backupURL
        let stampResult = MetadataEngine.updateDate(
            file: tmp,
            to: makeTestDate(),
            createBackup: true
        )
        XCTAssertTrue(stampResult.success,
                      "Stamp step should succeed: \(stampResult.message)")

        // Manually delete the backup to simulate a missing backup scenario
        try FileManager.default.removeItem(at: backupURL)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: backupURL.path),
            "Backup file should be deleted before calling undoStamp"
        )

        // Perform undo — backup is gone, so this should fail
        let (restored, failed) = MetadataEngine.undoStamp(results: [stampResult])

        XCTAssertEqual(restored, 0,
                       "undoStamp should report 0 restored files when backup is missing")
        XCTAssertEqual(failed, 1,
                       "undoStamp should report 1 failed file when backup is missing")
    }

    // MARK: - Requirement 4.2 (multi-file): undoStamp restores multiple files correctly

    func testUndoStampRestoresMultipleFiles() throws {
        // Create three independent temp copies
        let tmp1 = try makeTempCopy(resource: "sample", extension: "jpg")
        let tmp2 = try makeTempCopy(resource: "sample", extension: "jpg")
        let tmp3 = try makeTempCopy(resource: "sample", extension: "jpg")

        let backupURL1 = expectedBackupURL(for: tmp1)
        let backupURL2 = expectedBackupURL(for: tmp2)
        let backupURL3 = expectedBackupURL(for: tmp3)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: backupURL1)
            try? FileManager.default.removeItem(at: backupURL2)
            try? FileManager.default.removeItem(at: backupURL3)
        }

        let date = makeTestDate()
        let r1 = MetadataEngine.updateDate(file: tmp1, to: date, createBackup: true)
        let r2 = MetadataEngine.updateDate(file: tmp2, to: date, createBackup: true)
        let r3 = MetadataEngine.updateDate(file: tmp3, to: date, createBackup: true)

        XCTAssertTrue(r1.success && r2.success && r3.success,
                      "All three stamp operations should succeed")

        let (restored, failed) = MetadataEngine.undoStamp(results: [r1, r2, r3])

        XCTAssertEqual(restored, 3,
                       "undoStamp should restore all 3 files")
        XCTAssertEqual(failed, 0,
                       "undoStamp should report 0 failures when all backups exist")
    }

    // MARK: - Requirement 4.3 (mixed): undoStamp handles mix of present and missing backups

    func testUndoStampHandlesMixedBackupPresence() throws {
        let tmp1 = try makeTempCopy(resource: "sample", extension: "jpg")
        let tmp2 = try makeTempCopy(resource: "sample", extension: "jpg")

        let backupURL1 = expectedBackupURL(for: tmp1)
        let backupURL2 = expectedBackupURL(for: tmp2)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: backupURL1)
            try? FileManager.default.removeItem(at: backupURL2)
        }

        let date = makeTestDate()
        let r1 = MetadataEngine.updateDate(file: tmp1, to: date, createBackup: true)
        let r2 = MetadataEngine.updateDate(file: tmp2, to: date, createBackup: true)

        XCTAssertTrue(r1.success && r2.success, "Both stamp operations should succeed")

        // Delete the second backup to simulate a partial failure
        try FileManager.default.removeItem(at: backupURL2)

        let (restored, failed) = MetadataEngine.undoStamp(results: [r1, r2])

        XCTAssertEqual(restored, 1,
                       "undoStamp should restore 1 file (the one with a backup)")
        XCTAssertEqual(failed, 1,
                       "undoStamp should report 1 failure (the one with a missing backup)")
    }
}
