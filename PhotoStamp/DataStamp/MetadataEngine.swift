import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import CoreLocation
import UniformTypeIdentifiers

// MARK: - MetadataEngine
// Native replacement for exiftool — uses Apple's ImageIO and AVFoundation frameworks.
// Fully sandboxable, no subprocess execution.

struct MetadataEngine {

    // MARK: - Supported extensions

    static let supportedExtensions: Set<String> = [
        // Images
        "jpg", "jpeg", "tiff", "tif", "heic", "heif", "png", "avif",
        "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "pef", "raw",
        "bmp", "gif", "webp", "ico",
        // Videos (Apple-supported containers only)
        "mp4", "mov", "m4v", "3gp"
    ]

    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "3gp"]

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "tiff", "tif", "heic", "heif", "png", "avif",
        "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "pef", "raw",
        "bmp", "gif", "webp", "ico"
    ]

    // MARK: - Types (mirrors ExifTool types for UI compatibility)

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
        var isVideo: Bool { videoExtensions.contains(url.pathExtension.lowercased()) }
        var icon: String { isVideo ? "film" : "photo" }

        func isDuplicate(of target: Date) -> Bool {
            guard let raw = currentExifDate else { return false }
            let f = DateFormatter()
            f.dateFormat = "yyyy:MM:dd HH:mm:ss"
            guard let existing = f.date(from: raw) else { return false }
            return Calendar.current.isDate(existing, inSameDayAs: target)
        }
    }

    struct ExifData {
        var fields: [(key: String, value: String)] = []
    }

    // MARK: - Update date

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

        guard FileManager.default.fileExists(atPath: file.path) else {
            return FileResult(file: file, success: false, message: "File not found")
        }

        // Security-scoped access — access the parent directory so we can write temp files
        let parentDir = file.deletingLastPathComponent()
        let accessingFile = file.startAccessingSecurityScopedResource()
        let accessingDir = parentDir.startAccessingSecurityScopedResource()
        defer {
            if accessingFile { file.stopAccessingSecurityScopedResource() }
            if accessingDir { parentDir.stopAccessingSecurityScopedResource() }
        }

        // Backup
        var backupURL: URL? = nil
        if createBackup {
            let ext = file.pathExtension
            let bakURL = ext.isEmpty
                ? file.appendingPathExtension("bak")
                : file.deletingPathExtension().appendingPathExtension("bak_\(ext)")
            try? FileManager.default.copyItem(at: file, to: bakURL)
            backupURL = bakURL
        }

        let isVideo = videoExtensions.contains(file.pathExtension.lowercased())
        let success: Bool
        let message: String

        if isVideo {
            (success, message) = writeVideoDate(file: file, date: date, location: location)
        } else {
            (success, message) = writeImageDate(file: file, date: date, location: location)
        }

        guard success else {
            return FileResult(file: file, success: false, message: message, backupURL: backupURL)
        }

        // Rename
        var renamedURL: URL? = nil
        if rename {
            let datePart = formatDateForFilename(date)
            let seq = String(format: "%03d", renameIndex)
            let invalidChars = CharacterSet(charactersIn: "/\\:\0")
            let pre = renamePrepend.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: invalidChars).joined()
            let app = renameAppend.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: invalidChars).joined()
            let ext = file.pathExtension
            let newName = ext.isEmpty
                ? "\(pre)\(datePart)_\(seq)\(app)"
                : "\(pre)\(datePart)_\(seq)\(app).\(ext)"
            let newURL = file.deletingLastPathComponent().appendingPathComponent(newName)
            if (try? FileManager.default.moveItem(at: file, to: newURL)) != nil {
                renamedURL = newURL
            }
        }

        let displayURL = renamedURL ?? file
        let dateStr = formatDate(date)
        return FileResult(
            file: displayURL,
            success: true,
            message: "Updated to \(dateStr)\(renamedURL != nil ? " · Renamed" : "")",
            backupURL: backupURL,
            renamedURL: renamedURL
        )
    }

    // MARK: - Image date writing (ImageIO)

    private static func writeImageDate(
        file: URL,
        date: Date,
        location: CLLocationCoordinate2D?
    ) -> (Bool, String) {

        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else {
            return (false, "Could not read image file")
        }

        guard let sourceUTI = CGImageSourceGetType(source) else {
            return (false, "Unknown image format")
        }

        let imageCount = CGImageSourceGetCount(source)

        // Check if ImageIO can write this format — some formats are read-only
        let writableUTI: CFString
        let writableTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        if writableTypes.contains(sourceUTI as String) {
            writableUTI = sourceUTI
        } else {
            // Can't write this format natively — skip with a clear message
            return (false, "Format \(sourceUTI) is read-only. Convert to JPEG/HEIC first.")
        }

        // Read existing properties
        let existingProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        // Build updated EXIF dict
        var exif = existingProps[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let dateStr = formatDate(date)
        exif[kCGImagePropertyExifDateTimeOriginal] = dateStr
        exif[kCGImagePropertyExifDateTimeDigitized] = dateStr

        // Build updated TIFF dict
        var tiff = existingProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        tiff[kCGImagePropertyTIFFDateTime] = dateStr

        var newProps = existingProps
        newProps[kCGImagePropertyExifDictionary] = exif
        newProps[kCGImagePropertyTIFFDictionary] = tiff

        // GPS
        if let loc = location {
            var gps = existingProps[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
            gps[kCGImagePropertyGPSLatitude]     = abs(loc.latitude)
            gps[kCGImagePropertyGPSLatitudeRef]  = loc.latitude  >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude]    = abs(loc.longitude)
            gps[kCGImagePropertyGPSLongitudeRef] = loc.longitude >= 0 ? "E" : "W"
            newProps[kCGImagePropertyGPSDictionary] = gps
        }

        // Write to a temp file in the same directory
        let tempURL = file.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)_tmp.\(file.pathExtension)")

        guard let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, writableUTI, imageCount, nil) else {
            return (false, "Could not create image destination for \(writableUTI)")
        }

        for i in 0..<imageCount {
            if i == 0 {
                CGImageDestinationAddImageFromSource(dest, source, i, newProps as CFDictionary)
            } else {
                CGImageDestinationAddImageFromSource(dest, source, i, nil)
            }
        }

        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, "Could not finalize image metadata")
        }

        do {
            _ = try FileManager.default.replaceItemAt(file, withItemAt: tempURL)
            return (true, "OK")
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, "Write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Video date writing (AVFoundation)

    private static func writeVideoDate(
        file: URL,
        date: Date,
        location: CLLocationCoordinate2D?
    ) -> (Bool, String) {

        let asset = AVURLAsset(url: file)
        let composition = AVMutableMovie(url: file, options: nil)

        // Build metadata items
        var items: [AVMutableMetadataItem] = []

        func makeItem(_ key: String, _ keySpace: AVMetadataKeySpace, _ value: Any) -> AVMutableMetadataItem {
            let item = AVMutableMetadataItem()
            item.key = key as NSString
            item.keySpace = keySpace
            item.value = value as? NSCopying & NSObjectProtocol
            return item
        }

        let iso8601 = iso8601String(from: date)

        // QuickTime creation/modification dates
        items.append(makeItem(AVMetadataKey.commonKeyCreationDate.rawValue,
                               .common, iso8601))
        items.append(makeItem(AVMetadataKey.quickTimeMetadataKeyCreationDate.rawValue,
                               .quickTimeMetadata, iso8601))

        if let loc = location {
            let locStr = String(format: "%+.4f%+.4f/", loc.latitude, loc.longitude)
            items.append(makeItem(AVMetadataKey.commonKeyLocation.rawValue,
                                   .common, locStr))
        }

        composition.metadata = items

        // Export to temp file
        let tempURL = file.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)_tmp.\(file.pathExtension)")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            return (false, "Could not create export session")
        }

        exportSession.outputURL = tempURL
        exportSession.outputFileType = outputFileType(for: file.pathExtension)
        exportSession.metadata = items

        let semaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
            semaphore.signal()
        }
        // Timeout after 120 seconds to prevent indefinite blocking
        let waitResult = semaphore.wait(timeout: .now() + 120)
        if waitResult == .timedOut {
            exportSession.cancelExport()
            try? FileManager.default.removeItem(at: tempURL)
            return (false, "Video export timed out")
        }

        guard exportSession.status == .completed else {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, exportSession.error?.localizedDescription ?? "Export failed")
        }

        do {
            _ = try FileManager.default.replaceItemAt(file, withItemAt: tempURL)
            return (true, "OK")
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, error.localizedDescription)
        }
    }

    private static func outputFileType(for ext: String) -> AVFileType {
        switch ext.lowercased() {
        case "mp4", "m4v": return .mp4
        case "mov":        return .mov
        case "3gp":        return .mobile3GPP
        default:           return .mov
        }
    }

    // MARK: - Undo

    static func undoStamp(results: [FileResult]) -> (Int, Int) {
        var restored = 0, failed = 0
        for result in results {
            guard let bak = result.backupURL else { continue }
            let current = result.renamedURL ?? result.file
            do {
                try FileManager.default.removeItem(at: current)
                try FileManager.default.moveItem(at: bak, to: current)
                restored += 1
            } catch { failed += 1 }
        }
        return (restored, failed)
    }

    // MARK: - Read current date

    static func readCurrentDate(file: URL) -> String? {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }

        let ext = file.pathExtension.lowercased()

        if videoExtensions.contains(ext) {
            return readVideoDate(file: file)
        } else {
            return readImageDate(file: file)
        }
    }

    private static func readImageDate(file: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }

        // Convert "yyyy:MM:dd HH:mm:ss" → "MMM d, yyyy"
        let inFmt = DateFormatter(); inFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let outFmt = DateFormatter(); outFmt.dateStyle = .medium; outFmt.timeStyle = .none
        if let d = inFmt.date(from: dateStr) { return outFmt.string(from: d) }
        return dateStr
    }

    private static func readVideoDate(file: URL) -> String? {
        let asset = AVURLAsset(url: file)
        let items = asset.metadata(forFormat: .quickTimeMetadata)
        for item in items {
            if item.commonKey == .commonKeyCreationDate,
               let val = item.value as? String {
                // Parse ISO 8601
                let f = ISO8601DateFormatter()
                if let d = f.date(from: val) {
                    let out = DateFormatter(); out.dateStyle = .medium; out.timeStyle = .none
                    return out.string(from: d)
                }
                return val
            }
        }
        return nil
    }

    // MARK: - Read all metadata (preview panel)

    static func readAllMetadata(file: URL) -> ExifData {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }

        var fields: [(key: String, value: String)] = []
        let ext = file.pathExtension.lowercased()

        if videoExtensions.contains(ext) {
            let asset = AVURLAsset(url: file)
            for format in asset.availableMetadataFormats {
                for item in asset.metadata(forFormat: format) {
                    if let key = item.commonKey?.rawValue ?? (item.key as? String),
                       let value = item.value {
                        fields.append((key: key, value: "\(value)"))
                    }
                }
            }
        } else {
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            else { return ExifData() }

            func flatten(_ dict: [CFString: Any], prefix: String) {
                for (k, v) in dict {
                    let key = prefix.isEmpty ? (k as String) : "\(prefix) \(k as String)"
                    if let sub = v as? [CFString: Any] {
                        flatten(sub, prefix: key)
                    } else {
                        fields.append((key: key, value: "\(v)"))
                    }
                }
            }
            flatten(props, prefix: "")
        }

        return ExifData(fields: fields.sorted { $0.key < $1.key })
    }

    // MARK: - Collect files

    static func collectFiles(from urls: [URL], recursive: Bool = false) -> [FileItem] {
        var items: [FileItem] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                items += collectFromFolder(url, recursive: recursive)
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                items.append(FileItem(url: url))
            }
        }
        return items
    }

    private static func collectFromFolder(_ folder: URL, recursive: Bool) -> [FileItem] {
        var items: [FileItem] = []
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir)
            if isDir.boolValue && recursive {
                items += collectFromFolder(item, recursive: true)
            } else if !isDir.boolValue && supportedExtensions.contains(item.pathExtension.lowercased()) {
                items.append(FileItem(url: item))
            }
        }
        return items
    }

    // MARK: - Helpers

    static func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.string(from: date)
    }

    static func formatDateForFilename(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func iso8601String(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
