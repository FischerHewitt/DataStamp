import Testing
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 12.1, 12.2, 12.3

@Suite("ExifTool File Collection", .serialized)
struct ExifToolFileCollectionTests {

    // MARK: - Helpers

    /// Creates a unique temp directory, calls the body with its URL, then removes it.
    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    /// Creates an empty file at `dir/name`.
    @discardableResult
    private func touch(_ name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }

    // MARK: - Extension filtering (Requirement 12.1)

    @Test("collectFiles returns only supported extensions from a flat list of URLs")
    func extensionFilteringFlatURLs() throws {
        try withTempDir { dir in
            // Supported
            let jpg  = try touch("photo.jpg",  in: dir)
            let heic = try touch("photo.heic", in: dir)
            let mp4  = try touch("video.mp4",  in: dir)
            // Unsupported
            try touch("document.pdf",  in: dir)
            try touch("archive.zip",   in: dir)
            try touch("script.sh",     in: dir)
            try touch("noextension",   in: dir)

            let results = ExifTool.collectFiles(from: [jpg, heic, mp4,
                dir.appendingPathComponent("document.pdf"),
                dir.appendingPathComponent("archive.zip"),
                dir.appendingPathComponent("script.sh"),
                dir.appendingPathComponent("noextension")])

            let resultPaths = Set(results.map { $0.url.lastPathComponent })
            #expect(resultPaths == ["photo.jpg", "photo.heic", "video.mp4"],
                    "Expected only supported files, got \(resultPaths)")
        }
    }

    @Test("collectFiles result extensions are all in supportedExtensions")
    func allResultExtensionsAreSupported() throws {
        try withTempDir { dir in
            // Mix of supported and unsupported
            let allExts = ["jpg", "jpeg", "heic", "mp4", "mov",
                           "pdf", "txt", "zip", "exe", "dmg"]
            for ext in allExts {
                try touch("file.\(ext)", in: dir)
            }

            let results = ExifTool.collectFiles(from: [dir])
            for item in results {
                let ext = item.url.pathExtension.lowercased()
                #expect(ExifTool.supportedExtensions.contains(ext),
                        "Result contained unsupported extension: '\(ext)'")
            }
        }
    }

    // MARK: - Non-recursive scan (Requirement 12.2)

    @Test("collectFiles non-recursive returns only top-level files")
    func nonRecursiveReturnsTopLevelOnly() throws {
        try withTempDir { dir in
            // Top-level supported files
            try touch("top1.jpg", in: dir)
            try touch("top2.heic", in: dir)

            // Subdirectory with supported files
            let sub = dir.appendingPathComponent("subdir", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try touch("nested.jpg", in: sub)
            try touch("nested.mp4", in: sub)

            let results = ExifTool.collectFiles(from: [dir], recursive: false)
            let names = Set(results.map { $0.url.lastPathComponent })

            #expect(names == ["top1.jpg", "top2.heic"],
                    "Non-recursive scan should not include nested files, got \(names)")
        }
    }

    @Test("collectFiles non-recursive ignores deeply nested files")
    func nonRecursiveIgnoresDeeplyNested() throws {
        try withTempDir { dir in
            try touch("root.jpg", in: dir)

            let level1 = dir.appendingPathComponent("level1", isDirectory: true)
            try FileManager.default.createDirectory(at: level1, withIntermediateDirectories: true)
            let level2 = level1.appendingPathComponent("level2", isDirectory: true)
            try FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)

            try touch("deep.jpg", in: level1)
            try touch("deeper.jpg", in: level2)

            let results = ExifTool.collectFiles(from: [dir], recursive: false)
            let names = results.map { $0.url.lastPathComponent }

            #expect(names == ["root.jpg"],
                    "Non-recursive scan should only return root.jpg, got \(names)")
        }
    }

    // MARK: - Empty input (Requirement 12.3)

    @Test("collectFiles with empty URL array returns empty result")
    func emptyInputReturnsEmpty() {
        let results = ExifTool.collectFiles(from: [])
        #expect(results.isEmpty, "Expected empty result for empty input, got \(results.count) items")
    }

    @Test("collectFiles with empty directory returns empty result")
    func emptyDirectoryReturnsEmpty() throws {
        try withTempDir { dir in
            let results = ExifTool.collectFiles(from: [dir])
            #expect(results.isEmpty,
                    "Expected empty result for empty directory, got \(results.count) items")
        }
    }

    @Test("collectFiles with directory containing only unsupported files returns empty result")
    func directoryWithOnlyUnsupportedFilesReturnsEmpty() throws {
        try withTempDir { dir in
            try touch("readme.txt",   in: dir)
            try touch("data.csv",     in: dir)
            try touch("config.json",  in: dir)

            let results = ExifTool.collectFiles(from: [dir])
            #expect(results.isEmpty,
                    "Expected empty result when no supported files present, got \(results.count) items")
        }
    }
}
