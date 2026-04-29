import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import CoreLocation

// MARK: - MetadataEngine
// Uses the bundled ExifTool build for authoritative EXIF/QuickTime writes.
// User-facing stamping goes through ExifTool so verification tools see the same tags.

struct MetadataEngine {

    // MARK: - Supported extensions

    static let supportedExtensions: Set<String> = [
        // Images
        "jpg", "jpeg", "tiff", "tif", "heic", "heif", "png", "avif",
        "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "pef", "raw",
        "gif", "webp",
        // Videos — Apple-writable
        "mp4", "mov", "m4v", "3gp",
        // Videos — collected but may fail to write (clear error message)
        "avi", "mkv", "mts", "m2ts"
    ]

    static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "3gp", "avi", "mkv", "mts", "m2ts"
    ]

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "tiff", "tif", "heic", "heif", "png", "avif",
        "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "pef", "raw",
        "gif", "webp"
    ]

    // MARK: - Types (mirrors ExifTool types for UI compatibility)

    struct FileResult: Identifiable {
        let id = UUID()
        let file: URL
        let success: Bool
        let message: String
        var backupURL: URL? = nil
        var renamedURL: URL? = nil
        var originalURL: URL? = nil  // the pre-rename path, for undo
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
            // Try EXIF format first, then localized medium format
            let exifFmt = DateFormatter()
            exifFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let medFmt = DateFormatter()
            medFmt.dateStyle = .medium
            medFmt.timeStyle = .none

            let existing: Date?
            if let d = exifFmt.date(from: raw) {
                existing = d
            } else if let d = medFmt.date(from: raw) {
                existing = d
            } else {
                existing = nil
            }

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
            try? FileManager.default.removeItem(at: bakURL)  // remove stale backup if exists
            try? FileManager.default.copyItem(at: file, to: bakURL)
            backupURL = bakURL
        }

        let (success, message) = writeDateWithExifTool(file: file, date: date, location: location)

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
            // If target exists, append a suffix to avoid conflict
            var finalURL = newURL
            if FileManager.default.fileExists(atPath: finalURL.path) {
                let base = finalURL.deletingPathExtension().lastPathComponent
                let ext2 = finalURL.pathExtension
                var counter = 2
                while FileManager.default.fileExists(atPath: finalURL.path) {
                    let conflictName = ext2.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext2)"
                    finalURL = file.deletingLastPathComponent().appendingPathComponent(conflictName)
                    counter += 1
                }
            }
            if (try? FileManager.default.moveItem(at: file, to: finalURL)) != nil {
                renamedURL = finalURL
            }
        }

        let displayURL = renamedURL ?? file
        let dateStr = formatDate(date)
        var msg = "Updated to \(dateStr)"
        if rename {
            msg += renamedURL != nil ? " · Renamed" : " · Rename failed"
        }
        return FileResult(
            file: displayURL,
            success: true,
            message: msg,
            backupURL: backupURL,
            renamedURL: renamedURL,
            originalURL: rename ? file : nil
        )
    }

    // MARK: - ExifTool writing

    private static func writeDateWithExifTool(
        file: URL,
        date: Date,
        location: CLLocationCoordinate2D?
    ) -> (Bool, String) {

        guard bundledExiftoolPath() != nil else {
            return (false, "Bundled ExifTool was not found in the app resources.")
        }

        let perl = perlPath()
        guard FileManager.default.isExecutableFile(atPath: perl) else {
            return (false, "Perl interpreter not accessible at \(perl)")
        }

        let ext = file.pathExtension.lowercased()
        let isVideo = videoExtensions.contains(ext)
        let dateStr = formatDate(date)

        var args = ["-overwrite_original"]
        if isVideo {
            args += [
                "-QuickTime:CreateDate=\(dateStr)",
                "-QuickTime:ModifyDate=\(dateStr)",
                "-QuickTime:TrackCreateDate=\(dateStr)",
                "-QuickTime:TrackModifyDate=\(dateStr)",
                "-QuickTime:MediaCreateDate=\(dateStr)",
                "-QuickTime:MediaModifyDate=\(dateStr)",
                "-Keys:CreationDate=\(dateStr)",
                "-UserData:DateTimeOriginal=\(dateStr)"
            ]
        } else {
            args += [
                "-EXIF:DateTimeOriginal=\(dateStr)",
                "-EXIF:CreateDate=\(dateStr)",
                "-EXIF:ModifyDate=\(dateStr)",
                "-XMP:DateCreated=\(dateStr)",
                "-XMP:CreateDate=\(dateStr)",
                "-XMP:ModifyDate=\(dateStr)",
                "-IPTC:DateCreated=\(formatIPTCDate(date))",
                "-IPTC:TimeCreated=\(formatIPTCTime(date))"
            ]
        }

        if let loc = location {
            if isVideo {
                args.append("-Keys:GPSCoordinates=\(quickTimeLocationString(for: loc))")
            } else {
                args += [
                    "-GPSLatitude=\(loc.latitude)",
                    "-GPSLongitude=\(loc.longitude)"
                ]
            }
        }

        args.append(file.path)

        let (output, error, code) = runExiftool(args: args, timeout: 120)
        guard code == 0 else {
            let detail = error.isEmpty ? output : error
            return (false, cleanExiftoolMessage(detail, fallback: "ExifTool write failed"))
        }

        return (true, "OK")
    }

    // MARK: - Undo

    static func undoStamp(results: [FileResult]) -> (Int, Int) {
        var restored = 0, failed = 0
        for result in results {
            guard let bak = result.backupURL else { continue }
            let current = result.renamedURL ?? result.file
            // Restore to original path if file was renamed, otherwise restore in place
            let restoreTo = result.originalURL ?? current
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

        return readDateWithExifTool(file: file)
    }

    private static func readDateWithExifTool(file: URL) -> String? {
        let ext = file.pathExtension.lowercased()
        let tags: [String]

        if videoExtensions.contains(ext) {
            tags = [
                "-QuickTime:CreateDate",
                "-Keys:CreationDate",
                "-UserData:DateTimeOriginal",
                "-QuickTime:MediaCreateDate",
                "-QuickTime:TrackCreateDate"
            ]
        } else {
            tags = [
                "-DateTimeOriginal",
                "-CreateDate",
                "-ModifyDate",
                "-XMP:DateCreated",
                "-XMP:CreateDate"
            ]
        }

        let (out, _, code) = runExiftool(args: tags + ["-s3", file.path])
        guard code == 0, let raw = firstNonEmptyLine(in: out) else { return nil }

        let outFmt = DateFormatter()
        outFmt.dateStyle = .medium
        outFmt.timeStyle = .none

        for formatter in metadataDateFormatters() {
            if let date = formatter.date(from: raw) {
                return outFmt.string(from: date)
            }
        }

        return raw
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
        let outFmt = DateFormatter()
        outFmt.dateStyle = .medium
        outFmt.timeStyle = .none
        let iso = ISO8601DateFormatter()
        let exifFmt = DateFormatter()
        exifFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"

        let semaphore = DispatchSemaphore(value: 0)
        var result: String? = nil

        Task {
            do {
                let metadata = try await asset.load(.metadata)
                for item in metadata {
                    // commonKey is a sync property, key is sync too
                    let commonKey = item.commonKey
                    let key = item.key as? String

                    let isCreationDate =
                        commonKey == .commonKeyCreationDate ||
                        key == AVMetadataKey.quickTimeMetadataKeyCreationDate.rawValue ||
                        key == "com.apple.quicktime.creationdate" ||
                        key == AVMetadataKey.iTunesMetadataKeyReleaseDate.rawValue ||
                        key == "date"

                    guard isCreationDate else { continue }

                    // value needs async load
                    guard let val = try? await item.load(.value) as? String else { continue }

                    if let d = iso.date(from: val) {
                        result = outFmt.string(from: d)
                    } else if let d = exifFmt.date(from: val) {
                        result = outFmt.string(from: d)
                    } else {
                        result = val
                    }
                    break
                }
            } catch {}
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    // MARK: - Read all metadata (preview panel)

    static func readAllMetadata(file: URL) -> ExifData {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }

        let (out, _, code) = runExiftool(args: ["-a", "-s", "-G", file.path])
        if code == 0 {
            var exiftoolFields: [(key: String, value: String)] = []
            for line in out.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                if let colonRange = trimmed.range(of: " : ") {
                    let key = String(trimmed[..<colonRange.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                    let value = String(trimmed[colonRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    exiftoolFields.append((key: key, value: value))
                }
            }
            return ExifData(fields: exiftoolFields)
        }

        var fields: [(key: String, value: String)] = []
        let ext = file.pathExtension.lowercased()

        if videoExtensions.contains(ext) {
            let asset = AVURLAsset(url: file)
            let sem = DispatchSemaphore(value: 0)
            Task {
                if let metadata = try? await asset.load(.metadata) {
                    for item in metadata {
                        // commonKey and key are sync properties
                        let key = (item.key as? String)
                            ?? item.commonKey?.rawValue
                            ?? "Unknown"
                        // value needs async load
                        if let value = try? await item.load(.value) {
                            fields.append((key: key, value: "\(value)"))
                        }
                    }
                }
                sem.signal()
            }
            sem.wait()
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

    private static func formatIPTCDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd"
        return f.string(from: date)
    }

    private static func formatIPTCTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private static func quickTimeLocationString(for coord: CLLocationCoordinate2D) -> String {
        String(format: "%+.6f%+.6f/", coord.latitude, coord.longitude)
    }

    private static func firstNonEmptyLine(in text: String) -> String? {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func metadataDateFormatters() -> [DateFormatter] {
        let formats = [
            "yyyy:MM:dd HH:mm:ss",
            "yyyy:MM:dd HH:mm:ssXXXXX",
            "yyyy:MM:dd HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }

    private static func cleanExiftoolMessage(_ message: String, fallback: String) -> String {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    private static func runExiftool(args: [String], timeout: TimeInterval = 30) -> (String, String, Int32) {
        guard let exiftoolPath = bundledExiftoolPath() else {
            return ("", "Bundled ExifTool was not found in the app resources.", -1)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: perlPath())
        process.arguments = [exiftoolPath] + args

        var env = ProcessInfo.processInfo.environment
        env["PERL5LIB"] = URL(fileURLWithPath: exiftoolPath)
            .deletingLastPathComponent()
            .appendingPathComponent("lib")
            .path
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ("", "Failed to launch ExifTool: \(error.localizedDescription)", -1)
        }

        let pipeGroup = DispatchGroup()
        var stdoutData = Data()
        var stderrData = Data()

        pipeGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
            pipeGroup.leave()
        }

        pipeGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData = errPipe.fileHandleForReading.readDataToEndOfFile()
            pipeGroup.leave()
        }

        let timeoutWork = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(
            deadline: .now() + .milliseconds(Int(timeout * 1_000)),
            execute: timeoutWork
        )

        process.waitUntilExit()
        timeoutWork.cancel()
        pipeGroup.wait()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationReason == .uncaughtSignal {
            return (stdout, stderr.isEmpty ? "ExifTool timed out" : stderr, -1)
        }

        return (stdout, stderr, process.terminationStatus)
    }

    private static func bundledExiftoolPath() -> String? {
        if let path = Bundle.main.path(forResource: "exiftool", ofType: nil, inDirectory: "Resources") {
            return path
        }
        if let path = Bundle.main.path(forResource: "exiftool", ofType: nil) {
            return path
        }

        #if DEBUG
        let localPath = "DataStamp/Resources/exiftool"
        if FileManager.default.fileExists(atPath: localPath) {
            return localPath
        }
        #endif

        return nil
    }

    private static func perlPath() -> String {
        if FileManager.default.fileExists(atPath: "/usr/bin/perl") {
            return "/usr/bin/perl"
        }
        return "/usr/bin/perl5.34"
    }
}
