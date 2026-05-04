import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import CoreLocation
import UniformTypeIdentifiers

// MARK: - MetadataEngine
// Uses Apple's native ImageIO and AVFoundation frameworks.
// Fully sandboxable — no subprocess execution.

struct MetadataEngine {

    // MARK: - Supported extensions

    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "tiff", "tif", "heic", "heif", "png", "avif",
        "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "pef", "raw",
        "bmp", "gif", "webp",
        "mp4", "mov", "m4v", "3gp",
        "avi", "mkv", "mts", "m2ts"
    ]

    static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "3gp", "avi", "mkv", "mts", "m2ts"
    ]

    // MARK: - Types

    struct FileResult: Identifiable {
        let id = UUID()
        let file: URL
        let success: Bool
        let message: String
        var backupURL: URL? = nil
        var renamedURL: URL? = nil
        var originalURL: URL? = nil
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
            let exifFmt = DateFormatter()
            exifFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let medFmt = DateFormatter()
            medFmt.dateStyle = .medium
            medFmt.timeStyle = .none
            let existing = exifFmt.date(from: raw) ?? medFmt.date(from: raw)
            guard let existingDate = existing else { return false }
            return Calendar.current.isDate(existingDate, inSameDayAs: target)
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

        let parentDir = file.deletingLastPathComponent()
        let accessingFile = file.startAccessingSecurityScopedResource()
        let accessingDir  = parentDir.startAccessingSecurityScopedResource()
        defer {
            if accessingFile { file.stopAccessingSecurityScopedResource() }
            if accessingDir  { parentDir.stopAccessingSecurityScopedResource() }
        }

        // Backup
        var backupURL: URL? = nil
        if createBackup {
            let ext = file.pathExtension
            let bakURL = ext.isEmpty
                ? file.appendingPathExtension("bak")
                : file.deletingPathExtension().appendingPathExtension("bak_\(ext)")
            try? FileManager.default.removeItem(at: bakURL)
            try? FileManager.default.copyItem(at: file, to: bakURL)
            backupURL = bakURL
        }

        let isVideo = videoExtensions.contains(file.pathExtension.lowercased())
        let (success, message): (Bool, String)

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
            let pre = renamePrepend.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: invalidChars).joined()
            let app = renameAppend.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: invalidChars).joined()
            let ext = file.pathExtension
            let newName = ext.isEmpty
                ? "\(pre)\(datePart)_\(seq)\(app)"
                : "\(pre)\(datePart)_\(seq)\(app).\(ext)"
            var finalURL = file.deletingLastPathComponent().appendingPathComponent(newName)
            var counter = 2
            while FileManager.default.fileExists(atPath: finalURL.path) {
                let base = finalURL.deletingPathExtension().lastPathComponent
                let e    = finalURL.pathExtension
                let conflict = e.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(e)"
                finalURL = file.deletingLastPathComponent().appendingPathComponent(conflict)
                counter += 1
            }
            if (try? FileManager.default.moveItem(at: file, to: finalURL)) != nil {
                renamedURL = finalURL
            }
        }

        let displayURL = renamedURL ?? file
        let dateStr = formatDate(date)
        var msg = "Updated to \(dateStr)"
        if rename { msg += renamedURL != nil ? " · Renamed" : " · Rename failed" }
        return FileResult(
            file: displayURL, success: true, message: msg,
            backupURL: backupURL, renamedURL: renamedURL,
            originalURL: rename ? file : nil
        )
    }

    // MARK: - Image writing (ImageIO)

    private static func writeImageDate(
        file: URL, date: Date, location: CLLocationCoordinate2D?
    ) -> (Bool, String) {

        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else {
            return (false, "Could not read image")
        }
        guard let uti = CGImageSourceGetType(source) else {
            return (false, "Unknown image format")
        }

        // Verify ImageIO can write this UTI
        let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        guard writable.contains(uti as String) else {
            return (false, "Format is read-only — convert to JPEG/HEIC first")
        }

        let count = CGImageSourceGetCount(source)
        let existing = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        let dateStr = formatDate(date)

        var exif = existing[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        exif[kCGImagePropertyExifDateTimeOriginal]  = dateStr
        exif[kCGImagePropertyExifDateTimeDigitized] = dateStr

        var tiff = existing[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        tiff[kCGImagePropertyTIFFDateTime] = dateStr

        var props = existing
        props[kCGImagePropertyExifDictionary] = exif
        props[kCGImagePropertyTIFFDictionary] = tiff

        if let loc = location {
            var gps = existing[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
            gps[kCGImagePropertyGPSLatitude]     = abs(loc.latitude)
            gps[kCGImagePropertyGPSLatitudeRef]  = loc.latitude  >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude]    = abs(loc.longitude)
            gps[kCGImagePropertyGPSLongitudeRef] = loc.longitude >= 0 ? "E" : "W"
            props[kCGImagePropertyGPSDictionary] = gps
        }

        let tempURL = file.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).\(file.pathExtension)")

        guard let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, uti, count, nil) else {
            return (false, "Could not create destination")
        }

        for i in 0..<count {
            CGImageDestinationAddImageFromSource(dest, source, i, i == 0 ? props as CFDictionary : nil)
        }

        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, "Could not write metadata")
        }

        do {
            _ = try FileManager.default.replaceItemAt(file, withItemAt: tempURL)
            return (true, "OK")
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, "Write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Video writing (AVFoundation)

    private static func writeVideoDate(
        file: URL, date: Date, location: CLLocationCoordinate2D?
    ) -> (Bool, String) {

        let ext = file.pathExtension.lowercased()
        let writable: Set<String> = ["mp4", "mov", "m4v", "3gp"]
        guard writable.contains(ext) else {
            return (false, ".\(ext) is not writable — convert to MP4/MOV first")
        }

        let asset = AVURLAsset(url: file)

        // Load existing metadata (modern async API)
        let sem1 = DispatchSemaphore(value: 0)
        var existing: [AVMetadataItem] = []
        Task {
            existing = (try? await asset.load(.metadata)) ?? []
            sem1.signal()
        }
        sem1.wait()

        func makeItem(_ key: String, _ space: AVMetadataKeySpace, _ val: String) -> AVMutableMetadataItem {
            let item = AVMutableMetadataItem()
            item.key = key as NSString
            item.keySpace = space
            item.value = val as NSString
            return item
        }

        let iso = iso8601String(from: date)
        let keysToRemove: Set<String> = [
            AVMetadataKey.commonKeyCreationDate.rawValue,
            AVMetadataKey.quickTimeMetadataKeyCreationDate.rawValue,
            "com.apple.quicktime.creationdate"
        ]

        var filtered = existing.filter { item in
            let key = item.key as? String
            return item.commonKey != .commonKeyCreationDate &&
                !keysToRemove.contains(key ?? "")
        }

        var newItems: [AVMutableMetadataItem] = [
            makeItem(AVMetadataKey.commonKeyCreationDate.rawValue, .common, iso),
            makeItem(AVMetadataKey.quickTimeMetadataKeyCreationDate.rawValue, .quickTimeMetadata, iso)
        ]

        if let loc = location {
            filtered = filtered.filter {
                let key = $0.key as? String
                return $0.commonKey != .commonKeyLocation &&
                    key != AVMetadataKey.commonKeyLocation.rawValue
            }
            let locStr = String(format: "%+.6f%+.6f/", loc.latitude, loc.longitude)
            newItems.append(makeItem(AVMetadataKey.commonKeyLocation.rawValue, .common, locStr))
        }

        let merged = filtered + newItems

        // Use NSTemporaryDirectory() for the export output — this path is always
        // accessible from both the app sandbox and the AVAssetExportSession XPC service.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(".\(UUID().uuidString).\(file.pathExtension)")

        guard let session = AVAssetExportSession(asset: asset,
                                                  presetName: AVAssetExportPresetPassthrough) else {
            return (false, "Could not create export session")
        }

        session.outputURL      = tempURL
        session.outputFileType = avFileType(for: ext)
        session.metadata       = merged

        let sem2 = DispatchSemaphore(value: 0)
        session.exportAsynchronously { sem2.signal() }

        let timedOut = sem2.wait(timeout: .now() + 120) == .timedOut
        if timedOut {
            session.cancelExport()
            try? FileManager.default.removeItem(at: tempURL)
            return (false, "Export timed out")
        }

        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, session.error?.localizedDescription ?? "Export failed (status \(session.status.rawValue))")
        }

        // Verify the output file exists and has content
        guard FileManager.default.fileExists(atPath: tempURL.path),
              let tempSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path))?[.size] as? Int,
              tempSize > 0 else {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, "Export produced empty or missing output file")
        }

        do {
            _ = try FileManager.default.replaceItemAt(file, withItemAt: tempURL)
            return (true, "OK")
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return (false, error.localizedDescription)
        }
    }

    private static func avFileType(for ext: String) -> AVFileType {
        switch ext { case "mp4", "m4v": return .mp4; case "mov": return .mov; default: return .mov }
    }

    // MARK: - Undo

    static func undoStamp(results: [FileResult]) -> (Int, Int) {
        var restored = 0, failed = 0
        for r in results {
            guard let bak = r.backupURL else { continue }
            let current   = r.renamedURL ?? r.file
            let restoreTo = r.originalURL ?? current
            do {
                try FileManager.default.removeItem(at: current)
                try FileManager.default.moveItem(at: bak, to: restoreTo)
                restored += 1
            } catch { failed += 1 }
        }
        return (restored, failed)
    }

    // MARK: - Read current date

    static func readCurrentDate(file: URL) -> String? {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }

        if videoExtensions.contains(file.pathExtension.lowercased()) {
            return readVideoDate(file: file)
        } else {
            return readImageDate(file: file)
        }
    }

    private static func readImageDate(file: URL) -> String? {
        guard let src = CGImageSourceCreateWithURL(file as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let exif  = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let raw   = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }

        let inFmt  = DateFormatter(); inFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let outFmt = DateFormatter(); outFmt.dateStyle = .medium; outFmt.timeStyle = .none
        return inFmt.date(from: raw).map { outFmt.string(from: $0) } ?? raw
    }

    private static func readVideoDate(file: URL) -> String? {
        let asset  = AVURLAsset(url: file)
        let outFmt = DateFormatter(); outFmt.dateStyle = .medium; outFmt.timeStyle = .none
        let iso    = ISO8601DateFormatter()
        let exifFmt = DateFormatter(); exifFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"

        let sem = DispatchSemaphore(value: 0)
        var result: String?

        Task {
            if let metadata = try? await asset.load(.metadata) {
                for item in metadata {
                    let commonKey = item.commonKey
                    let key = item.key as? String
                    let isDate = commonKey == .commonKeyCreationDate
                        || key == AVMetadataKey.quickTimeMetadataKeyCreationDate.rawValue
                        || key == "com.apple.quicktime.creationdate"
                        || key == AVMetadataKey.iTunesMetadataKeyReleaseDate.rawValue
                    guard isDate, let val = try? await item.load(.value) as? String else { continue }
                    result = iso.date(from: val).map { outFmt.string(from: $0) }
                        ?? exifFmt.date(from: val).map { outFmt.string(from: $0) }
                        ?? val
                    break
                }
            }
            sem.signal()
        }
        sem.wait()
        return result
    }

    // MARK: - Read all metadata (preview panel)

    static func readAllMetadata(file: URL) -> ExifData {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }

        var fields: [(key: String, value: String)] = []

        if videoExtensions.contains(file.pathExtension.lowercased()) {
            let asset = AVURLAsset(url: file)
            let sem = DispatchSemaphore(value: 0)
            Task {
                if let metadata = try? await asset.load(.metadata) {
                    for item in metadata {
                        let key = (item.key as? String) ?? item.commonKey?.rawValue ?? "Unknown"
                        if let val = try? await item.load(.value) {
                            fields.append((key: key, value: "\(val)"))
                        }
                    }
                }
                sem.signal()
            }
            sem.wait()
        } else {
            guard let src = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
            else { return ExifData() }

            func flatten(_ dict: [CFString: Any], prefix: String) {
                for (k, v) in dict {
                    let key = prefix.isEmpty ? (k as String) : "\(prefix) \(k as String)"
                    if let sub = v as? [CFString: Any] { flatten(sub, prefix: key) }
                    else { fields.append((key: key, value: "\(v)")) }
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
            let acc = url.startAccessingSecurityScopedResource()
            defer { if acc { url.stopAccessingSecurityScopedResource() } }
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
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [FileItem] = []
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
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
