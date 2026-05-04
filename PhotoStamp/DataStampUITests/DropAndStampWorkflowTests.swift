import XCTest
@testable import DataStamp

final class DropAndStampWorkflowTests: XCTestCase {

    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataStampWorkflowTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func testWorkflowStartsAtDropView() {
        XCTAssertEqual(ContentView.initialAppView, .drop)
    }

    func testSupportedDroppedFilesMoveWorkflowToFileList() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let jpg = directory.appendingPathComponent("scan.jpg")
        let txt = directory.appendingPathComponent("notes.txt")
        try Data([0xFF, 0xD8, 0xFF]).write(to: jpg)
        try Data("notes".utf8).write(to: txt)

        let collected = MetadataEngine.collectFiles(from: [directory], recursive: false)
        XCTAssertEqual(collected.map(\.url.lastPathComponent), ["scan.jpg"])

        let nextView = ContentView.destinationAfterLoadingFiles(
            foundNewItems: !collected.isEmpty,
            currentView: .drop
        )
        XCTAssertEqual(nextView, .fileList)
    }

    func testUnsupportedDroppedFilesKeepWorkflowAtCurrentView() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let txt = directory.appendingPathComponent("notes.txt")
        try Data("notes".utf8).write(to: txt)

        let collected = MetadataEngine.collectFiles(from: [directory], recursive: false)
        XCTAssertTrue(collected.isEmpty)

        let nextView = ContentView.destinationAfterLoadingFiles(
            foundNewItems: !collected.isEmpty,
            currentView: .drop
        )
        XCTAssertEqual(nextView, .drop)
    }

    func testResetReturnsWorkflowToDropView() {
        XCTAssertEqual(ContentView.resetDestination, .drop)
    }
}
