import Foundation
import CoreLocation

struct ExifTool {

    static let supportedExtensions = MetadataEngine.supportedExtensions
    static let videoExtensions = MetadataEngine.videoExtensions

    struct FileResult: Identifiable {
        let id = UUID()
        let file: URL
        let success: Bool
        let message: String
        var backupURL: URL? = nil
        var renamedURL: URL? = nil
        var fileName: String { file.lastPathComponent }
    }

    struct FileItem: Identifiable {
        let id = UUID()
        let url: URL
        var isSelected: Bool = true
        var currentExifDate: String? = nil
        var isLoadingDate: Bool = true

        var fileName: String { url.lastPathComponent }
        var isVideo: Bool { ExifTool.videoExtensions.contains(url.pathExtension.lowercased()) }
        var icon: String { isVideo ? "film" : "photo" }

        func isDuplicate(of target: Date) -> Bool {
            var item = MetadataEngine.FileItem(url: url)
            item.isSelected = isSelected
            item.currentExifDate = currentExifDate
            item.isLoadingDate = isLoadingDate
            return item.isDuplicate(of: target)
        }
    }

    struct ExifData {
        var fields: [(key: String, value: String)] = []
    }

    static func updateDate(
        file: URL,
        to date: Date,
        rename: Bool = false,
        renameIndex: Int = 1,
        renamePrepend: String = "",
        renameAppend: String = "",
        location: CLLocationCoordinate2D? = nil,
        createBackup: Bool = false
    ) -> FileResult {
        let result = MetadataEngine.updateDate(
            file: file,
            to: date,
            rename: rename,
            renameIndex: renameIndex,
            renamePrepend: renamePrepend,
            renameAppend: renameAppend,
            location: location,
            createBackup: createBackup
        )

        return FileResult(
            file: result.file,
            success: result.success,
            message: result.message,
            backupURL: result.backupURL,
            renamedURL: result.renamedURL
        )
    }

    static func undoStamp(results: [FileResult]) -> (Int, Int) {
        let mapped = results.map {
            MetadataEngine.FileResult(
                file: $0.file,
                success: $0.success,
                message: $0.message,
                backupURL: $0.backupURL,
                renamedURL: $0.renamedURL
            )
        }
        return MetadataEngine.undoStamp(results: mapped)
    }

    static func readCurrentDate(file: URL) -> String? {
        MetadataEngine.readCurrentDate(file: file)
    }

    static func readAllMetadata(file: URL) -> ExifData {
        let data = MetadataEngine.readAllMetadata(file: file)
        return ExifData(fields: data.fields)
    }

    static func collectFiles(from urls: [URL], recursive: Bool = false) -> [FileItem] {
        MetadataEngine.collectFiles(from: urls, recursive: recursive).map {
            var item = FileItem(url: $0.url)
            item.isSelected = $0.isSelected
            item.currentExifDate = $0.currentExifDate
            item.isLoadingDate = $0.isLoadingDate
            return item
        }
    }

    static func formatDate(_ date: Date) -> String {
        MetadataEngine.formatDate(date)
    }

    static func formatDateForFilename(_ date: Date) -> String {
        MetadataEngine.formatDateForFilename(date)
    }
}
