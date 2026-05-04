import XCTest
@testable import DataStamp

// Feature: photostamp-test-suite
// Validates: Requirements 20.5

/// Performance tests for MetadataEngine.updateDate on batches of files.
/// Uses XCTMeasure blocks to capture baseline performance metrics.
final class PerformanceTests: XCTestCase {

    // MARK: - Properties

    /// Ten temp copies of sample.jpg, set up once per test method.
    private var tempFiles: [URL] = []

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        let bundle = Bundle(for: PerformanceTests.self)
        let fixture = try XCTUnwrap(
            bundle.url(forResource: "sample", withExtension: "jpg"),
            "sample.jpg fixture not found in test bundle"
        )

        tempFiles = []
        for _ in 0..<10 {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            try FileManager.default.copyItem(at: fixture, to: tmp)
            tempFiles.append(tmp)
        }

        addTeardownBlock { [weak self] in
            guard let files = self?.tempFiles else { return }
            for url in files {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Performance Tests

    /// Measures the time to stamp all 10 fixture files using MetadataEngine.updateDate.
    /// The measure block runs multiple iterations; after the first, files are already stamped,
    /// which is acceptable for establishing a performance baseline.
    func testUpdateDatePerformance() {
        let date = Date()

        measure {
            for url in tempFiles {
                _ = MetadataEngine.updateDate(file: url, to: date)
            }
        }
    }
}
