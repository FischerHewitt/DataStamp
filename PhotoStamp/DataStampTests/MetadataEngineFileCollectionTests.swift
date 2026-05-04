import Testing
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 5.1, 5.2, 5.3, 5.4

@Suite("MetadataEngine File Collection", .serialized)
struct MetadataEngineFileCollectionTests {

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

    // MARK: - Extension filtering (Requirement 5.1)

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

            let results = MetadataEngine.collectFiles(from: [jpg, heic, mp4,
                dir.appendingPathComponent("document.pdf"),
                dir.appendingPathComponent("archive.zip"),
                dir.appendingPathComponent("script.sh"),
                dir.appendingPathComponent("noextension")])

            let resultPaths = Set(results.map { $0.url.lastPathComponent })
            #expect(resultPaths == ["photo.jpg", "photo.heic", "video.mp4"],
                    "Expected only supported files, got \(resultPaths)")
        }
    }

    @Test("collectFiles returns only supported extensions from a directory")
    func extensionFilteringFromDirectory() throws {
        try withTempDir { dir in
            // Supported
            try touch("a.jpg",  in: dir)
            try touch("b.png",  in: dir)
            try touch("c.mov",  in: dir)
            // Unsupported
            try touch("d.txt",  in: dir)
            try touch("e.docx", in: dir)

            let results = MetadataEngine.collectFiles(from: [dir])
            let extensions = Set(results.map { $0.url.pathExtension.lowercased() })

            for ext in extensions {
                #expect(MetadataEngine.supportedExtensions.contains(ext),
                        "Unexpected extension '\(ext)' in results")
            }
            #expect(results.count == 3,
                    "Expected 3 supported files, got \(results.count)")
        }
    }

    @Test("collectFiles result extensions are all in supportedExtensions")
    func allResultExtensionsAreSupported() throws {
        try withTempDir { dir in
            // Mix of supported and unsupported
            let allExts = ["jpg", "jpeg", "png", "heic", "mp4", "mov",
                           "pdf", "txt", "zip", "exe", "dmg"]
            for ext in allExts {
                try touch("file.\(ext)", in: dir)
            }

            let results = MetadataEngine.collectFiles(from: [dir])
            for item in results {
                let ext = item.url.pathExtension.lowercased()
                #expect(MetadataEngine.supportedExtensions.contains(ext),
                        "Result contained unsupported extension: '\(ext)'")
            }
        }
    }

    // MARK: - Non-recursive scan (Requirement 5.2)

    @Test("collectFiles non-recursive returns only top-level files")
    func nonRecursiveReturnsTopLevelOnly() throws {
        try withTempDir { dir in
            // Top-level supported files
            try touch("top1.jpg", in: dir)
            try touch("top2.png", in: dir)

            // Subdirectory with supported files
            let sub = dir.appendingPathComponent("subdir", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try touch("nested.jpg", in: sub)
            try touch("nested.heic", in: sub)

            let results = MetadataEngine.collectFiles(from: [dir], recursive: false)
            let names = Set(results.map { $0.url.lastPathComponent })

            #expect(names == ["top1.jpg", "top2.png"],
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

            let results = MetadataEngine.collectFiles(from: [dir], recursive: false)
            let names = results.map { $0.url.lastPathComponent }

            #expect(names == ["root.jpg"],
                    "Non-recursive scan should only return root.jpg, got \(names)")
        }
    }

    // MARK: - Recursive scan (Requirement 5.3)

    @Test("collectFiles recursive returns files from nested subdirectories")
    func recursiveReturnsNestedFiles() throws {
        try withTempDir { dir in
            try touch("root.jpg", in: dir)

            let sub = dir.appendingPathComponent("sub", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try touch("sub.png", in: sub)

            let subsub = sub.appendingPathComponent("subsub", isDirectory: true)
            try FileManager.default.createDirectory(at: subsub, withIntermediateDirectories: true)
            try touch("deep.heic", in: subsub)

            let results = MetadataEngine.collectFiles(from: [dir], recursive: true)
            let names = Set(results.map { $0.url.lastPathComponent })

            #expect(names == ["root.jpg", "sub.png", "deep.heic"],
                    "Recursive scan should include all nested files, got \(names)")
        }
    }

    @Test("collectFiles recursive count is greater than or equal to non-recursive count")
    func recursiveCountGeNonRecursive() throws {
        try withTempDir { dir in
            try touch("a.jpg", in: dir)

            let sub = dir.appendingPathComponent("sub", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try touch("b.jpg", in: sub)

            let nonRecursive = MetadataEngine.collectFiles(from: [dir], recursive: false)
            let recursive    = MetadataEngine.collectFiles(from: [dir], recursive: true)

            #expect(recursive.count >= nonRecursive.count,
                    "Recursive count (\(recursive.count)) should be ≥ non-recursive count (\(nonRecursive.count))")
        }
    }

    @Test("collectFiles recursive finds files in multiple sibling subdirectories")
    func recursiveFindsFilesInSiblingSubdirs() throws {
        try withTempDir { dir in
            let subA = dir.appendingPathComponent("A", isDirectory: true)
            let subB = dir.appendingPathComponent("B", isDirectory: true)
            try FileManager.default.createDirectory(at: subA, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: subB, withIntermediateDirectories: true)

            try touch("a1.jpg", in: subA)
            try touch("a2.mov", in: subA)
            try touch("b1.png", in: subB)

            let results = MetadataEngine.collectFiles(from: [dir], recursive: true)
            let names = Set(results.map { $0.url.lastPathComponent })

            #expect(names == ["a1.jpg", "a2.mov", "b1.png"],
                    "Recursive scan should find files in all sibling subdirs, got \(names)")
        }
    }

    // MARK: - Empty input (Requirement 5.4)

    @Test("collectFiles with empty URL array returns empty result")
    func emptyInputReturnsEmpty() {
        let results = MetadataEngine.collectFiles(from: [])
        #expect(results.isEmpty, "Expected empty result for empty input, got \(results.count) items")
    }

    @Test("collectFiles with empty directory returns empty result")
    func emptyDirectoryReturnsEmpty() throws {
        try withTempDir { dir in
            let results = MetadataEngine.collectFiles(from: [dir])
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

            let results = MetadataEngine.collectFiles(from: [dir])
            #expect(results.isEmpty,
                    "Expected empty result when no supported files present, got \(results.count) items")
        }
    }
}
