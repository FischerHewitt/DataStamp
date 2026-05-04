import Foundation
import CoreLocation

struct ExifTool {

    // MARK: - Supported extensions

    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "tiff", "tif", "heic", "heif", "png", "raw",
        "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "pef",
        "mp4", "mov", "m4v", "avi", "mkv", "mts", "m2ts", "3gp"
    ]

    static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "mts", "m2ts", "3gp"
    ]

    // MARK: - Types

    struct FileResult: Identifiable {
        let id = UUID()
        let file: URL
        let success: Bool
        let message: String
        /// The backup file created before modification (for undo).
        var backupURL: URL? = nil
        /// The new URL if the file was renamed.
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

    /// Full EXIF metadata for the preview panel.
    struct ExifData {
        var fields: [(key: String, value: String)] = []
    }

    // MARK: - Update

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
        // Verify file still exists before processing
        guard FileManager.default.fileExists(atPath: file.path) else {
            return FileResult(file: file, success: false, message: "File not found")
        }

        let dateStr = formatDate(date)
        let ext = file.pathExtension.lowercased()
        let isVideo = videoExtensions.contains(ext)

        // Create backup before modifying
        var backupURL: URL? = nil
        if createBackup {
            let ext = file.pathExtension
            let bakURL: URL
            if ext.isEmpty {
                bakURL = file.appendingPathExtension("bak")
            } else {
                bakURL = file.deletingPathExtension()
                    .appendingPathExtension("bak_\(ext)")
            }
            try? FileManager.default.copyItem(at: file, to: bakURL)
            backupURL = bakURL
        }

        var args = ["-overwrite_original"]
        if isVideo {
            args += [
                "-QuickTime:CreateDate=\(dateStr)",
                "-QuickTime:ModifyDate=\(dateStr)",
                "-QuickTime:TrackCreateDate=\(dateStr)",
                "-QuickTime:TrackModifyDate=\(dateStr)",
                "-QuickTime:MediaCreateDate=\(dateStr)",
                "-QuickTime:MediaModifyDate=\(dateStr)",
            ]
        } else {
            args += [
                "-DateTimeOriginal=\(dateStr)",
                "-CreateDate=\(dateStr)",
                "-DateTimeDigitized=\(dateStr)",
            ]
        }

        // GPS tags
        if let loc = location {
            let latRef = loc.latitude  >= 0 ? "N" : "S"
            let lonRef = loc.longitude >= 0 ? "E" : "W"
            args += [
                "-GPSLatitude=\(abs(loc.latitude))",
                "-GPSLatitudeRef=\(latRef)",
                "-GPSLongitude=\(abs(loc.longitude))",
                "-GPSLongitudeRef=\(lonRef)",
            ]
        }

        args.append(file.path)

        let (output, error, code) = runExiftool(args: args)

        if code != 0 {
            let msg = error.isEmpty ? output : error
            return FileResult(file: file, success: false,
                              message: msg.trimmingCharacters(in: .whitespacesAndNewlines),
                              backupURL: backupURL)
        }

        // Rename if requested
        var renamedURL: URL? = nil
        if rename {
            let datePart = formatDateForFilename(date)
            let seq = String(format: "%03d", renameIndex)
            // Sanitize prepend/append — remove path separators and invalid chars
            let invalidChars = CharacterSet(charactersIn: "/\\:\0")
            let pre = renamePrepend.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: invalidChars).joined()
            let app = renameAppend.trimmingCharacters(in: .whitespacesAndNewlines)
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
        return FileResult(
            file: displayURL,
            success: true,
            message: "Updated to \(dateStr)\(renamedURL != nil ? " · Renamed" : "")",
            backupURL: backupURL,
            renamedURL: renamedURL
        )
    }

    // MARK: - Undo

    /// Restore all backup files from a set of results.
    /// Returns (restored count, failed count).
    static func undoStamp(results: [FileResult]) -> (Int, Int) {
        var restored = 0
        var failed = 0

        for result in results {
            guard let bak = result.backupURL else { continue }
            // The current file might have been renamed
            let current = result.renamedURL ?? result.file
            do {
                // Remove the stamped file and restore the backup
                try FileManager.default.removeItem(at: current)
                try FileManager.default.moveItem(at: bak, to: current)
                restored += 1
            } catch {
                failed += 1
            }
        }
        return (restored, failed)
    }

    // MARK: - Read metadata

    static func readCurrentDate(file: URL) -> String? {
        let ext = file.pathExtension.lowercased()
        let tag = videoExtensions.contains(ext) ? "-QuickTime:CreateDate" : "-DateTimeOriginal"
        let (out, _, _) = runExiftool(args: [tag, "-s3", file.path])
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let outFmt = DateFormatter()
        outFmt.dateStyle = .medium
        outFmt.timeStyle = .none

        if let d = inFmt.date(from: trimmed) {
            return outFmt.string(from: d)
        }
        return trimmed
    }

    /// Read all EXIF fields for the preview panel.
    static func readAllMetadata(file: URL) -> ExifData {
        let (out, _, _) = runExiftool(args: ["-s", "-G", file.path])
        var fields: [(key: String, value: String)] = []

        for line in out.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Format: "[Group] TagName : Value"
            if let colonRange = trimmed.range(of: " : ") {
                let key = String(trimmed[trimmed.startIndex..<colonRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                fields.append((key: key, value: value))
            }
        }
        return ExifData(fields: fields)
    }

    // MARK: - Collect files

    static func collectFiles(from urls: [URL], recursive: Bool = false) -> [FileItem] {
        var items: [FileItem] = []
        for url in urls {
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
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.string(from: date)
    }

    static func formatDateForFilename(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func runExiftool(args: [String]) -> (String, String, Int32) {
        let exiftoolPath = bundledExiftoolPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [exiftoolPath] + args

        var env = ProcessInfo.processInfo.environment
        env["PERL5LIB"] = (exiftoolPath as NSString).deletingLastPathComponent + "/lib"
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ("", "Failed to launch exiftool: \(error.localizedDescription)", -1)
        }

        // Timeout: kill the process if it hangs for more than 30 seconds
        let deadline = DispatchTime.now() + .seconds(30)
        let timeoutWork = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: deadline, execute: timeoutWork)

        process.waitUntilExit()
        timeoutWork.cancel()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (stdout, stderr, process.terminationStatus)
    }

    static func bundledExiftoolPath() -> String {
        if let p = Bundle.main.path(forResource: "exiftool", ofType: nil, inDirectory: "Resources") { return p }
        if let p = Bundle.main.path(forResource: "exiftool", ofType: nil) { return p }
        return "/opt/homebrew/bin/exiftool"
    }
}
