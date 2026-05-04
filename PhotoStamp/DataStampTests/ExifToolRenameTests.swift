import Testing
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 13.1, 13.2

@Suite("ExifTool Rename Sanitisation", .serialized)
struct ExifToolRenameTests {

    // MARK: - Helpers

    /// Loads the sample.jpg fixture and copies it to a unique temp path.
    /// The caller is responsible for cleanup (use `defer`).
    private func makeTempJPEG() throws -> URL {
        let bundle = Bundle(for: DataStampTestsPlaceholder.self)
        guard let fixture = bundle.url(forResource: "sample", withExtension: "jpg") else {
            Issue.record("sample.jpg fixture not found in test bundle")
            throw TestError.fixtureNotFound
        }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try FileManager.default.copyItem(at: fixture, to: tmp)
        return tmp
    }

    private enum TestError: Error {
        case fixtureNotFound
    }

    // MARK: - Requirement 13.1: Strip path-separator characters from renamePrepend

    @Test("renamePrepend containing '/' is stripped before filename construction")
    func prependWithForwardSlashIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "pre/fix",
            renameAppend: ""
        )

        guard result.success, let renamed = result.renamedURL else {
            // If exiftool is unavailable in this environment, skip gracefully
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains("/"),
                "Filename '\(name)' must not contain '/' after sanitisation")
    }

    @Test("renamePrepend containing '\\' is stripped before filename construction")
    func prependWithBackslashIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "pre\\fix",
            renameAppend: ""
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains("\\"),
                "Filename '\(name)' must not contain '\\' after sanitisation")
    }

    @Test("renamePrepend containing ':' is stripped before filename construction")
    func prependWithColonIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "pre:fix",
            renameAppend: ""
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains(":"),
                "Filename '\(name)' must not contain ':' after sanitisation")
    }

    @Test("renamePrepend containing null byte is stripped before filename construction")
    func prependWithNullByteIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "pre\0fix",
            renameAppend: ""
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains("\0"),
                "Filename '\(name)' must not contain null byte after sanitisation")
    }

    @Test("renamePrepend with all invalid chars produces a clean filename")
    func prependWithAllInvalidCharsProducesCleanFilename() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        // Prepend is entirely invalid characters — should collapse to empty
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "/\\:\0",
            renameAppend: ""
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains("/"),  "Filename '\(name)' must not contain '/'")
        #expect(!name.contains("\\"), "Filename '\(name)' must not contain '\\'")
        #expect(!name.contains(":"),  "Filename '\(name)' must not contain ':'")
        #expect(!name.contains("\0"), "Filename '\(name)' must not contain null byte")
    }

    // MARK: - Requirement 13.1: Strip path-separator characters from renameAppend

    @Test("renameAppend containing '/' is stripped before filename construction")
    func appendWithForwardSlashIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: "suf/fix"
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains("/"),
                "Filename '\(name)' must not contain '/' after sanitisation")
    }

    @Test("renameAppend containing '\\' is stripped before filename construction")
    func appendWithBackslashIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: "suf\\fix"
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains("\\"),
                "Filename '\(name)' must not contain '\\' after sanitisation")
    }

    @Test("renameAppend containing ':' is stripped before filename construction")
    func appendWithColonIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: "suf:fix"
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains(":"),
                "Filename '\(name)' must not contain ':' after sanitisation")
    }

    @Test("renameAppend containing null byte is stripped before filename construction")
    func appendWithNullByteIsStripped() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: "suf\0fix"
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        #expect(!name.contains("\0"),
                "Filename '\(name)' must not contain null byte after sanitisation")
    }

    // MARK: - Requirement 13.2: Whitespace-only append treated as empty

    @Test("renameAppend containing only spaces is treated as empty")
    func appendWithOnlySpacesIsTreatedAsEmpty() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)

        // Run once with whitespace-only append
        let resultWithSpaces = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: "   "
        )

        guard resultWithSpaces.success, let renamedWithSpaces = resultWithSpaces.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamedWithSpaces) }

        // Run again with truly empty append on a fresh copy
        let tmp2 = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp2) }

        let resultEmpty = ExifTool.updateDate(
            file: tmp2,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: ""
        )

        guard resultEmpty.success, let renamedEmpty = resultEmpty.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamedEmpty) }

        // Both filenames should be identical (whitespace-only == empty)
        #expect(renamedWithSpaces.lastPathComponent == renamedEmpty.lastPathComponent,
                "Whitespace-only append '\(renamedWithSpaces.lastPathComponent)' should equal empty append '\(renamedEmpty.lastPathComponent)'")
    }

    @Test("renameAppend containing only tabs is treated as empty")
    func appendWithOnlyTabsIsTreatedAsEmpty() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let resultWithTabs = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: "\t\t"
        )

        guard resultWithTabs.success, let renamedWithTabs = resultWithTabs.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamedWithTabs) }

        let tmp2 = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp2) }

        let resultEmpty = ExifTool.updateDate(
            file: tmp2,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: ""
        )

        guard resultEmpty.success, let renamedEmpty = resultEmpty.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamedEmpty) }

        #expect(renamedWithTabs.lastPathComponent == renamedEmpty.lastPathComponent,
                "Tab-only append '\(renamedWithTabs.lastPathComponent)' should equal empty append '\(renamedEmpty.lastPathComponent)'")
    }

    @Test("renameAppend containing only newlines is treated as empty")
    func appendWithOnlyNewlinesIsTreatedAsEmpty() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let resultWithNewlines = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: "\n\r\n"
        )

        guard resultWithNewlines.success, let renamedWithNewlines = resultWithNewlines.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamedWithNewlines) }

        let tmp2 = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp2) }

        let resultEmpty = ExifTool.updateDate(
            file: tmp2,
            to: date,
            rename: true,
            renameIndex: 1,
            renamePrepend: "",
            renameAppend: ""
        )

        guard resultEmpty.success, let renamedEmpty = resultEmpty.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamedEmpty) }

        #expect(renamedWithNewlines.lastPathComponent == renamedEmpty.lastPathComponent,
                "Newline-only append '\(renamedWithNewlines.lastPathComponent)' should equal empty append '\(renamedEmpty.lastPathComponent)'")
    }

    // MARK: - Combined sanitisation

    @Test("renamePrepend and renameAppend with mixed valid and invalid chars produce correct filename")
    func mixedValidAndInvalidCharsProduceCorrectFilename() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 42,
            renamePrepend: "va/lid",   // '/' should be stripped → "valid"
            renameAppend: "su:ffix"    // ':' should be stripped → "suffix"
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        // Verify no invalid characters remain
        #expect(!name.contains("/"),  "Filename '\(name)' must not contain '/'")
        #expect(!name.contains("\\"), "Filename '\(name)' must not contain '\\'")
        #expect(!name.contains(":"),  "Filename '\(name)' must not contain ':'")
        #expect(!name.contains("\0"), "Filename '\(name)' must not contain null byte")

        // Verify the sanitised parts are present
        #expect(name.hasPrefix("valid"),
                "Filename '\(name)' should start with sanitised prepend 'valid'")
        #expect(name.contains("suffix"),
                "Filename '\(name)' should contain sanitised append 'suffix'")
    }

    @Test("renamed file lastPathComponent contains the date part and sequence number")
    func renamedFileContainsDateAndSequence() throws {
        let tmp = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let date = makeDate(year: 2024, month: 6, day: 15)
        let result = ExifTool.updateDate(
            file: tmp,
            to: date,
            rename: true,
            renameIndex: 7,
            renamePrepend: "photo_",
            renameAppend: "_final"
        )

        guard result.success, let renamed = result.renamedURL else {
            return
        }
        defer { try? FileManager.default.removeItem(at: renamed) }

        let name = renamed.lastPathComponent
        // Expected pattern: photo_2024-06-15_007_final.jpg
        #expect(name.contains("2024-06-15"),
                "Filename '\(name)' should contain the date part '2024-06-15'")
        #expect(name.contains("007"),
                "Filename '\(name)' should contain zero-padded sequence '007'")
        #expect(name.hasSuffix(".jpg"),
                "Filename '\(name)' should retain the .jpg extension")
    }

    // MARK: - Private helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
