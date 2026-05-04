import Testing
import SwiftCheck
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite, Property 6: File collection filters to supported extensions only
// Validates: Requirements 5.1

// MARK: - Arbitrary extension strings for SwiftCheck

/// A small pool of file extensions (supported and unsupported) used as the generator alphabet.
/// SwiftCheck will draw from this pool to build arbitrary extension lists.
private let candidateExtensions: [String] = [
    // Supported image extensions
    "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "avif",
    "cr2", "cr3", "nef", "arw", "dng", "bmp", "gif", "webp",
    // Supported video extensions
    "mp4", "mov", "m4v", "3gp", "avi", "mkv", "mts", "m2ts",
    // Unsupported
    "pdf", "txt", "docx", "xlsx", "zip", "tar", "gz", "dmg",
    "sh", "py", "js", "html", "css", "json", "xml", "csv",
    "exe", "dll", "so", "dylib", "plist", "strings"
]

/// Generates a non-empty list of extensions drawn from `candidateExtensions`.
private let arbitraryExtensionList: Gen<[String]> =
    Gen<Int>.choose((1, 20)).flatMap { count in
        sequence(
            (0..<count).map { _ in
                Gen<Int>.choose((0, candidateExtensions.count - 1))
                    .map { candidateExtensions[$0] }
            }
        )
    }

// MARK: - Property test suite

@Suite("MetadataEngine File Collection — Property Tests", .serialized)
struct MetadataEngineFileCollectionPropertyTests {

    // MARK: - Helpers

    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    // MARK: - Property 6

    /// Property 6: File collection filters to supported extensions only.
    ///
    /// For any list of file extensions (supported and unsupported), creating empty files
    /// with those extensions in a temp directory and calling `collectFiles` must return
    /// only `FileItem` values whose `pathExtension` is in `MetadataEngine.supportedExtensions`.
    @Test("Property 6: collectFiles returns only supported extensions for arbitrary extension lists")
    func property6_fileCollectionFiltersToSupportedExtensionsOnly() throws {
        // Run 100 iterations via SwiftCheck
        property("File collection filters to supported extensions only") <- forAll(arbitraryExtensionList) { extensions in
            // Create a fresh temp dir for each iteration
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            guard (try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)) != nil else {
                return false
            }
            defer { try? FileManager.default.removeItem(at: dir) }

            // Create one empty file per extension
            for (index, ext) in extensions.enumerated() {
                let url = dir.appendingPathComponent("file_\(index).\(ext)")
                FileManager.default.createFile(atPath: url.path, contents: Data())
            }

            // Collect files from the directory
            let results = MetadataEngine.collectFiles(from: [dir], recursive: false)

            // Every result must have a supported extension
            for item in results {
                let ext = item.url.pathExtension.lowercased()
                if !MetadataEngine.supportedExtensions.contains(ext) {
                    return false
                }
            }

            // The result count must equal the number of supported extensions in the input
            let expectedCount = extensions.filter {
                MetadataEngine.supportedExtensions.contains($0.lowercased())
            }.count

            return results.count == expectedCount
        }
    }

    /// Corollary: no unsupported extension ever appears in the results, regardless of input.
    @Test("Property 6 (corollary): no unsupported extension appears in collectFiles results")
    func property6_corollary_noUnsupportedExtensionInResults() throws {
        property("No unsupported extension in collectFiles results") <- forAll(arbitraryExtensionList) { extensions in
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            guard (try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)) != nil else {
                return false
            }
            defer { try? FileManager.default.removeItem(at: dir) }

            for (index, ext) in extensions.enumerated() {
                let url = dir.appendingPathComponent("file_\(index).\(ext)")
                FileManager.default.createFile(atPath: url.path, contents: Data())
            }

            let results = MetadataEngine.collectFiles(from: [dir], recursive: false)

            return results.allSatisfy {
                MetadataEngine.supportedExtensions.contains($0.url.pathExtension.lowercased())
            }
        }
    }
}
