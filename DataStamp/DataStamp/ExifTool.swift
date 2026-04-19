import Foundation

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
        var fileName: String { file.lastPathComponent }
    }

    struct FileItem: Identifiable {
        let id = UUID()
        let url: URL
        var isSelected: Bool = true
        var fileName: String { url.lastPathComponent }
        var isVideo: Bool { videoExtensions.contains(url.pathExtension.lowercased()) }
        var icon: String { isVideo ? "film" : "photo" }
    }

    // MARK: - Public API

    static func updateDate(file: URL, to date: Date) -> FileResult {
        let dateStr = formatDate(date)
        let ext = file.pathExtension.lowercased()
        let isVideo = videoExtensions.contains(ext)

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
        args.append(file.path)

        let (output, error, code) = runExiftool(args: args)
        if code == 0 {
            return FileResult(file: file, success: true, message: "Updated to \(dateStr)")
        } else {
            let msg = error.isEmpty ? output : error
            return FileResult(file: file, success: false,
                              message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

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

        let sorted = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }

        for item in sorted {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir)

            if isDir.boolValue && recursive {
                // Recurse into subfolder
                items += collectFromFolder(item, recursive: true)
            } else if !isDir.boolValue && supportedExtensions.contains(item.pathExtension.lowercased()) {
                items.append(FileItem(url: item))
            }
        }

        return items
    }

    // MARK: - Private

    static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
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
            process.waitUntilExit()
        } catch {
            return ("", "Failed to launch exiftool: \(error.localizedDescription)", -1)
        }

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
