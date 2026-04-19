import SwiftUI
import AppKit

// MARK: - Expanded confirm sheet content

struct ConfirmSheetExpanded: View {

    let selectedItems: [ExifTool.FileItem]
    let stampDate: Date
    let duplicateCount: Int
    let settings: SettingsStore
    @Binding var renameOnStamp: Bool
    @Binding var renamePrepend: String
    @Binding var renameAppend: String
    @Binding var canUndo: Bool
    let renamePreviewExample: String
    let previewRename: (ExifTool.FileItem, Int) -> String
    let formattedStampDate: String
    let formattedStampTime: String
    let fileTypeSummary: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var selectedFileIndex: Int = 0
    @Environment(\.uiScale) private var scale

    private var selectedFile: ExifTool.FileItem? {
        guard !selectedItems.isEmpty, selectedItems.indices.contains(selectedFileIndex) else { return nil }
        return selectedItems[selectedFileIndex]
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Left column: summary + options ──────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                // Header
                header
                Divider()

                // Summary rows
                summaryRows
                Divider()

                // File list (scrollable, selectable)
                fileList
                Divider()

                // Options
                optionsSection
                Divider()

                // Buttons
                footerButtons
            }
            .frame(width: 340)

            Divider()

            // ── Right column: selected file detail ───────────────────────
            VStack(spacing: 0) {
                if let file = selectedFile {
                    FileDetailPanel(item: file, stampDate: stampDate, scale: scale)
                } else {
                    Spacer()
                    Text("Select a file to preview")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        }
        .frame(width: 820, height: 600)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 36 * scale, height: 36 * scale)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16 * scale))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Confirm Stamp")
                    .font(.headline)
                Text("Original files will be modified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Summary rows

    private var summaryRows: some View {
        VStack(spacing: 0) {
            compactRow(icon: "doc.on.doc",     label: "Files",    value: "\(selectedItems.count)")
            Divider().padding(.leading, 36)
            compactRow(icon: "calendar",        label: "Date",     value: formattedStampDate)
            Divider().padding(.leading, 36)
            compactRow(icon: "clock",           label: "Time",     value: formattedStampTime)
            Divider().padding(.leading, 36)
            compactRow(icon: "square.grid.2x2", label: "Types",    value: fileTypeSummary)
            if duplicateCount > 0 {
                Divider().padding(.leading, 36)
                compactRow(icon: "exclamationmark.triangle",
                           label: "Duplicates",
                           value: "\(duplicateCount)",
                           valueColor: .orange)
            }
            compactRow(icon: "mappin.and.ellipse",
                       label: "Location",
                       value: settings.hasLocation
                           ? (settings.savedLocationLabel.isEmpty ? "Set" : settings.savedLocationLabel)
                           : "None",
                       valueColor: settings.hasLocation ? .dsPinActive : .secondary)
        }
        .padding(.vertical, 2)
    }

    private func compactRow(icon: String, label: String, value: String,
                            valueColor: Color = .primary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.dsAccent)
                .font(.system(size: 12 * scale))
                .frame(width: 16 * scale)
                .padding(.leading, 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 7)
    }

    // MARK: - File list

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(selectedItems.enumerated()), id: \.offset) { idx, item in
                    Button {
                        selectedFileIndex = idx
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.isVideo ? "film" : "photo")
                                .font(.system(size: 11 * scale))
                                .foregroundColor(item.isVideo ? .purple : .dsAccent)
                                .frame(width: 14 * scale)
                                .padding(.leading, 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(renameOnStamp
                                     ? previewRename(item, idx + 1)
                                     : item.fileName)
                                    .font(.system(size: 11 * scale, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(selectedFileIndex == idx ? .dsAccent : .primary)

                                if let d = item.currentExifDate {
                                    Text(d)
                                        .font(.system(size: 10 * scale))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if item.isDuplicate(of: stampDate) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10 * scale))
                                    .foregroundStyle(.orange)
                                    .padding(.trailing, 12)
                            }
                        }
                        .padding(.vertical, 6)
                        .background(selectedFileIndex == idx
                                    ? Color.dsAccent.opacity(0.08)
                                    : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if idx < selectedItems.count - 1 {
                        Divider().padding(.leading, 38)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(spacing: 0) {
            // Rename toggle
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .foregroundColor(.dsAccent)
                    .font(.system(size: 12 * scale))
                    .frame(width: 16 * scale)
                    .padding(.leading, 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rename to date")
                        .font(.caption.weight(.medium))
                    Text(renamePreviewExample)
                        .font(.system(size: 10 * scale))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                DSToggle(isOn: $renameOnStamp)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 8)

            if renameOnStamp {
                Divider().padding(.leading, 32)
                HStack(spacing: 6) {
                    Color.clear.frame(width: 16 * scale).padding(.leading, 16)
                    Text("Pre:")
                        .font(.system(size: 10 * scale))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    TextField("e.g. vacation_", text: $renamePrepend)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11 * scale, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1))
                    Text("Post:")
                        .font(.system(size: 10 * scale))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                    TextField("e.g. _final", text: $renameAppend)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11 * scale, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1))
                }
                .padding(.vertical, 6)
                .padding(.trailing, 16)
            }

            Divider().padding(.leading, 32)

            // Undo toggle
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundColor(.dsAccent)
                    .font(.system(size: 12 * scale))
                    .frame(width: 16 * scale)
                    .padding(.leading, 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Enable undo")
                        .font(.caption.weight(.medium))
                    Text("Saves .bak copies")
                        .font(.system(size: 10 * scale))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DSToggle(isOn: $canUndo)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack {
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.escape)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Spacer()

            Button {
                onConfirm()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "stamp")
                        .font(.system(size: 13 * scale))
                    Text("Confirm & Stamp")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LinearGradient(colors: [.dsAccent, .dsMid],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - File Detail Panel (right column)

struct FileDetailPanel: View {

    let item: ExifTool.FileItem
    let stampDate: Date
    let scale: Double

    @State private var thumbnail: NSImage? = nil
    @State private var exifFields: [(key: String, value: String)] = []
    @State private var isLoading = true

    // Key EXIF fields to highlight
    private let priorityKeys = [
        "DateTimeOriginal", "CreateDate", "Make", "Model",
        "ImageSize", "MegaPixels", "ExposureTime", "FNumber",
        "ISO", "FocalLength", "GPSLatitude", "GPSLongitude",
        "FileSize", "FileType", "ColorSpace", "Orientation"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Image preview + filename header
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: 75 * scale, height: 75 * scale)
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                    if let img = thumbnail {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75 * scale, height: 75 * scale)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: item.isVideo ? "film" : "photo")
                            .font(.system(size: 28 * scale))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 3) {
                    Text(item.fileName)
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200)

                    if item.isDuplicate(of: stampDate) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10 * scale))
                                .foregroundStyle(.orange)
                            Text("Already at this date")
                                .font(.system(size: 10 * scale))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

            Divider()

            // EXIF fields
            if isLoading {
                Spacer()
                ProgressView("Reading metadata…")
                    .font(.caption)
                Spacer()
            } else if exifFields.isEmpty {
                Spacer()
                Text("No metadata found")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(exifFields, id: \.key) { field in
                            HStack(alignment: .top, spacing: 8) {
                                Text(cleanKey(field.key))
                                    .font(.system(size: 10 * scale, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .leading)
                                    .lineLimit(1)
                                Text(field.value)
                                    .font(.system(size: 10 * scale))
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                    .textSelection(.enabled)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            Divider().padding(.leading, 14)
                        }
                    }
                }
            }
        }
        .onAppear { loadData() }
        .onChange(of: item.url) { _ in loadData() }
    }

    private func loadData() {
        isLoading = true
        thumbnail = nil
        exifFields = []

        let url = item.url
        DispatchQueue.global(qos: .userInitiated).async {
            // Load thumbnail
            let img = loadThumbnail(url: url)

            // Load EXIF — show priority fields first, then rest
            let data = ExifTool.readAllMetadata(file: url)
            let priority = data.fields.filter { f in
                priorityKeys.contains(where: { f.key.contains($0) })
            }
            let rest = data.fields.filter { f in
                !priorityKeys.contains(where: { f.key.contains($0) })
            }
            let ordered = priority + rest

            DispatchQueue.main.async {
                thumbnail = img
                exifFields = ordered
                isLoading = false
            }
        }
    }

    private func loadThumbnail(url: URL) -> NSImage? {
        // Try QuickLook thumbnail first
        let size = CGSize(width: 150, height: 150)
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceThumbnailMaxPixelSize: 150,
               kCGImageSourceCreateThumbnailWithTransform: true
           ] as CFDictionary) {
            return NSImage(cgImage: cgImg, size: size)
        }
        return nil
    }

    private func cleanKey(_ key: String) -> String {
        // Strip group prefix like "[EXIF] " → "DateTimeOriginal"
        if let bracket = key.lastIndex(of: " ") {
            return String(key[key.index(after: bracket)...])
        }
        return key
    }
}
