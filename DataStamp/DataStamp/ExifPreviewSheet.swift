import SwiftUI

/// Sheet showing all EXIF/metadata fields for a single file.
struct ExifPreviewSheet: View {

    let file: ExifTool.FileItem
    @State private var exifData: ExifTool.ExifData? = nil
    @State private var isLoading = true
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredFields: [(key: String, value: String)] {
        guard let data = exifData else { return [] }
        if searchText.isEmpty { return data.fields }
        return data.fields.filter {
            $0.key.localizedCaseInsensitiveContains(searchText) ||
            $0.value.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(file.isVideo
                              ? Color.purple.opacity(0.15)
                              : Color.dsAccent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: file.isVideo ? "film" : "photo")
                        .foregroundColor(file.isVideo ? .purple : .dsAccent)
                        .font(.system(size: 18, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(file.url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search fields…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Reading metadata…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if filteredFields.isEmpty {
                Spacer()
                Text(searchText.isEmpty ? "No metadata found." : "No matching fields.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFields, id: \.key) { field in
                            ExifFieldRow(key: field.key, value: field.value)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("\(filteredFields.count) field\(filteredFields.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 520, height: 560)
        .onAppear {
            let url = file.url
            DispatchQueue.global(qos: .userInitiated).async {
                let data = ExifTool.readAllMetadata(file: url)
                DispatchQueue.main.async {
                    exifData = data
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - ExifFieldRow

struct ExifFieldRow: View {
    let key: String
    let value: String
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
                .lineLimit(2)

            Text(value)
                .font(.system(size: 12))
                .lineLimit(3)
                .textSelection(.enabled)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    ExifPreviewSheet(file: ExifTool.FileItem(url: URL(fileURLWithPath: "/tmp/test.jpg")))
}
