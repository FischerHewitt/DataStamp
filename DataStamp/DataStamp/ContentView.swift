import SwiftUI

// MARK: - Brand colours
extension Color {
    static let dsNavy      = Color(red: 0.06, green: 0.14, blue: 0.35)
    static let dsMid       = Color(red: 0.12, green: 0.32, blue: 0.62)
    static let dsSky       = Color(red: 0.20, green: 0.52, blue: 0.82)
    static let dsAccent    = Color(red: 0.10, green: 0.55, blue: 0.95)
    static let dsLight     = Color(red: 0.75, green: 0.90, blue: 1.00)
}

// MARK: - ContentView

struct ContentView: View {

    enum AppView { case drop, fileList, results, settings }
    

    @ObservedObject private var settings = SettingsStore.shared
    @State private var selectedDate: Date = Date()
    @State private var fileItems: [ExifTool.FileItem] = []
    @State private var results: [ExifTool.FileResult] = []
    @State private var isTargetingDrop = false
    @State private var isProcessing = false
    @State private var showConfirmSheet = false
    @State private var currentView: AppView = .drop
    @State private var previousView: AppView = .drop
    @State private var dateHasError: Bool = false

    private var selectedItems: [ExifTool.FileItem] { fileItems.filter { $0.isSelected } }
    private var allSelected: Bool { fileItems.allSatisfy { $0.isSelected } }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().overlay(Color.dsAccent.opacity(0.3))

            switch currentView {
            case .drop:     dropView
            case .fileList: fileListView
            case .results:  resultsView
            case .settings: SettingsView()
            }
        }
        .frame(minWidth: 620, minHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .sheet(isPresented: $showConfirmSheet) { confirmSheet }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: 0) {
            // Logo + name
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.dsAccent, .dsMid],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "photo.badge.arrow.down.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("DataStamp")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }

            Spacer()

            // Date picker — hidden on settings view
            if currentView != .settings {
                HStack(spacing: 8) {
                    Text("Stamp date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    DateStampPicker(date: $selectedDate, hasError: $dateHasError)
                    if dateHasError {
                        Text("Fix date first")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if currentView != .drop {
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 12)

                    Button {
                        resetToStart()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Start over")
                }

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 12)
            }

            // Settings gear
            Button {
                if currentView == .settings {
                    // Return to wherever we were
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentView = previousView
                    }
                } else {
                    previousView = currentView
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentView = .settings
                    }
                }
            } label: {
                Image(systemName: currentView == .settings ? "xmark.circle.fill" : "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(currentView == .settings ? .dsAccent : .secondary)
            }
            .buttonStyle(.plain)
            .help(currentView == .settings ? "Close Settings" : "Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Drop view

    private var dropView: some View {
        ZStack {
            // Subtle gradient wash
            LinearGradient(
                colors: [Color.dsNavy.opacity(0.04), Color.dsSky.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Drop zone card
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isTargetingDrop
                              ? Color.dsAccent.opacity(0.10)
                              : Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.dsMid.opacity(isTargetingDrop ? 0.25 : 0.08),
                                radius: isTargetingDrop ? 20 : 8, x: 0, y: 4)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isTargetingDrop
                                ? Color.dsAccent
                                : Color.dsMid.opacity(0.30),
                            style: StrokeStyle(lineWidth: 2,
                                               dash: isTargetingDrop ? [] : [10, 6])
                        )

                    VStack(spacing: 18) {
                        // Stacked icon
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.dsAccent.opacity(0.15), .dsMid.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 88, height: 88)

                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(colors: [.dsAccent, .dsMid],
                                                   startPoint: .top, endPoint: .bottom))
                        }

                        VStack(spacing: 6) {
                            Text("Drop photos, videos, or a folder")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))

                            Text("Supports JPEG, HEIC, PNG, RAW, MP4, MOV and more")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            openFilePicker()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Browse Files")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 9)
                            .background(
                                LinearGradient(colors: [.dsAccent, .dsMid],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: .dsAccent.opacity(0.35), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(44)

                    // Full-area invisible tap target
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { openFilePicker() }
                }
                .frame(maxWidth: 480)
                .frame(height: 300)
                .onDrop(of: [.fileURL], isTargeted: $isTargetingDrop, perform: handleDrop)
                .animation(.easeInOut(duration: 0.15), value: isTargetingDrop)

                // Supported formats hint
                HStack(spacing: 16) {
                    ForEach(["Photos", "Videos", "Folders"], id: \.self) { label in
                        HStack(spacing: 5) {
                            Image(systemName: label == "Photos" ? "photo" :
                                             label == "Videos" ? "film" : "folder")
                                .font(.caption)
                                .foregroundColor(.dsAccent)
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(32)
        }
    }

    // MARK: - File list view

    private var fileListView: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(allSelected ? "Deselect All" : "Select All") {
                    toggleSelectAll()
                }
                .buttonStyle(.plain)
                .foregroundColor(.dsAccent)
                .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(selectedItems.count) of \(fileItems.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($fileItems) { $item in
                        FileRow(item: $item)
                        Divider().padding(.leading, 56)
                    }
                }
            }

            Divider()

            // Bottom bar
            HStack {
                Button {
                    openFilePicker()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle")
                        Text("Add More")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showConfirmSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stamp")
                        Text("Stamp \(selectedItems.count) File\(selectedItems.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [.dsAccent, .dsMid],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .dsAccent.opacity(0.30), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(selectedItems.isEmpty || dateHasError)
                .opacity(selectedItems.isEmpty || dateHasError ? 0.5 : 1)            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Confirm sheet

    private var confirmSheet: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Confirm Stamp")
                        .font(.headline)
                    Text("Original files will be modified. This cannot be undone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)

            Divider()

            // Summary rows
            VStack(spacing: 0) {
                confirmRow(icon: "doc.on.doc", label: "Files", value: "\(selectedItems.count)")
                Divider().padding(.leading, 44)
                confirmRow(icon: "calendar", label: "New date", value: formattedTargetDate())
                Divider().padding(.leading, 44)
                confirmRow(icon: "square.grid.2x2", label: "Types", value: fileTypeSummary())
            }
            .padding(.vertical, 4)

            Divider()

            // File list — static under 8, scrollable at 8+
            Group {
                if selectedItems.count < 8 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(selectedItems) { item in
                            filePreviewRow(item: item)
                        }
                    }
                    .padding(16)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(selectedItems) { item in
                                filePreviewRow(item: item)
                            }
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            // Buttons
            HStack {
                Button("Cancel") { showConfirmSheet = false }
                    .keyboardShortcut(.escape)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showConfirmSheet = false
                    runUpdate()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stamp")
                        Text("Confirm & Stamp")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: [.dsAccent, .dsMid],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
            }
            .padding(24)
        }
        .frame(width: 440)
    }

    private func confirmRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.dsAccent)
                .frame(width: 20)
                .padding(.leading, 24)
            Text(label)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .padding(.trailing, 24)
        }
        .padding(.vertical, 11)
    }

    private func filePreviewRow(item: ExifTool.FileItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.isVideo ? "film" : "photo")
                .foregroundStyle(item.isVideo ? Color.purple : Color.dsAccent)
                .font(.caption)
                .frame(width: 16)
            Text(item.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Results view

    private var resultsView: some View {
        VStack(spacing: 0) {
            let succeeded = results.filter { $0.success }.count
            let failed    = results.filter { !$0.success }.count

            // Summary banner
            HStack(spacing: 20) {
                resultBadge(count: succeeded, label: "stamped", icon: "checkmark.circle.fill", color: .green)
                if failed > 0 {
                    resultBadge(count: failed, label: "failed", icon: "xmark.circle.fill", color: .red)
                }
                Spacer()
                Text("\(results.count) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { result in
                        ResultRow(result: result)
                        Divider().padding(.leading, 48)
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    resetToStart()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Start Over")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: [.dsAccent, .dsMid],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func resultBadge(count: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count) \(label)")
                .font(.subheadline.weight(.medium))
        }
    }

    // MARK: - Actions

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }
        group.notify(queue: .main) { loadFiles(from: urls) }
        return true
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Choose photos, videos, or a folder"
        panel.prompt = "Add to DataStamp"
        if panel.runModal() == .OK { loadFiles(from: panel.urls) }
    }

    private func loadFiles(from urls: [URL]) {
        let newItems = ExifTool.collectFiles(from: urls, recursive: settings.includeSubfolders)
        guard !newItems.isEmpty else { return }
        let existing = Set(fileItems.map { $0.url.path })
        fileItems.append(contentsOf: newItems.filter { !existing.contains($0.url.path) })
        withAnimation(.easeInOut(duration: 0.2)) { currentView = .fileList }
    }

    private func toggleSelectAll() {
        let v = !allSelected
        for i in fileItems.indices { fileItems[i].isSelected = v }
    }

    private func runUpdate() {
        let toProcess = selectedItems
        isProcessing = true
        results = []
        withAnimation { currentView = .results }

        DispatchQueue.global(qos: .userInitiated).async {
            let date = selectedDate
            let r = toProcess.map { ExifTool.updateDate(file: $0.url, to: date) }
            DispatchQueue.main.async {
                withAnimation { results = r; isProcessing = false }
            }
        }
    }

    private func resetToStart() {
        fileItems = []; results = []; isProcessing = false
        withAnimation { currentView = .drop }
    }

    private func formattedTargetDate() -> String {
        let f = DateFormatter(); f.dateStyle = .long
        return f.string(from: selectedDate)
    }

    private func fileTypeSummary() -> String {
        let imgs = selectedItems.filter { !$0.isVideo }.count
        let vids = selectedItems.filter { $0.isVideo }.count
        var p: [String] = []
        if imgs > 0 { p.append("\(imgs) photo\(imgs == 1 ? "" : "s")") }
        if vids > 0 { p.append("\(vids) video\(vids == 1 ? "" : "s")") }
        return p.joined(separator: ", ")
    }
}

// MARK: - FileRow

struct FileRow: View {
    @Binding var item: ExifTool.FileItem

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $item.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.isVideo
                          ? Color.purple.opacity(0.12)
                          : Color.dsAccent.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(item.isVideo ? Color.purple : Color.dsAccent)
            }

            Text(item.fileName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(item.url.deletingLastPathComponent().lastPathComponent)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { item.isSelected.toggle() }
    }
}

// MARK: - ResultRow

struct ResultRow: View {
    let result: ExifTool.FileResult

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(result.success ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: result.success ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(result.success ? Color.green : Color.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
}
