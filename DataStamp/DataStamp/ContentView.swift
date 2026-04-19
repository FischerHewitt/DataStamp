import SwiftUI
import CoreLocation

// MARK: - Brand colours
extension Color {
    static let dsNavy   = Color(red: 0.06, green: 0.14, blue: 0.35)
    static let dsMid    = Color(red: 0.12, green: 0.32, blue: 0.62)
    static let dsSky    = Color(red: 0.20, green: 0.52, blue: 0.82)
    static let dsAccent = Color(red: 0.10, green: 0.55, blue: 0.95)
    static let dsLight  = Color(red: 0.75, green: 0.90, blue: 1.00)
    static let dsPin    = Color(red: 0.85, green: 0.30, blue: 0.20) // warm terracotta red for location pin
}

// MARK: - ContentView

struct ContentView: View {

    enum AppView { case drop, fileList, results, settings }

    @ObservedObject private var settings = SettingsStore.shared

    @State private var selectedDate: Date = Date()
    @State private var selectedTime: Date = Date()          // used when timeMode == .custom
    @State private var fileItems: [ExifTool.FileItem] = []
    @State private var results: [ExifTool.FileResult] = []
    @State private var isTargetingDrop = false
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalToProcess = 0
    @State private var showConfirmSheet = false
    @State private var showRecentDates = false
    @State private var currentView: AppView = .drop
    @State private var previousView: AppView = .drop
    @State private var dateHasError: Bool = false

    // New feature state
    @State private var renameOnStamp: Bool = false
    @State private var isGeocodingLocation: Bool = false
    @State private var lastResults: [ExifTool.FileResult] = []
    @State private var canUndo: Bool = false
    @State private var selectedPreviewItem: ExifTool.FileItem? = nil
    @State private var showLocationPicker: Bool = false

    private var selectedItems: [ExifTool.FileItem] { fileItems.filter { $0.isSelected } }
    private var allSelected: Bool { fileItems.allSatisfy { $0.isSelected } }

    /// The final date+time that will be stamped, combining date picker + time setting.
    private var stampDate: Date {
        settings.applyTime(to: selectedDate,
                           customTime: settings.timeMode == .custom ? selectedTime : nil)
    }

    /// Count of selected items whose current EXIF date already matches the target.
    private var duplicateCount: Int {
        selectedItems.filter { $0.isDuplicate(of: stampDate) }.count
    }

    /// Location coordinate from persisted settings, if set.
    private var currentLocationCoord: CLLocationCoordinate2D? {
        guard settings.hasLocation else { return nil }
        return CLLocationCoordinate2D(latitude: settings.savedLocationLat,
                                      longitude: settings.savedLocationLon)
    }

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
        .frame(minWidth: 640, minHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .sheet(isPresented: $showConfirmSheet) { confirmSheet }
        .sheet(item: $selectedPreviewItem) { item in
            ExifPreviewSheet(file: item)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet { coord, label in
                settings.savedLocationLat   = coord.latitude
                settings.savedLocationLon   = coord.longitude
                settings.savedLocationLabel = label
                settings.hasLocation        = true
            }
        }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: 0) {
            // Logo + name
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [.dsAccent, .dsMid],
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

            if currentView != .settings {
                // Date picker + recent dates
                HStack(spacing: 6) {
                    Text("Date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DateStampPicker(date: $selectedDate, hasError: $dateHasError)

                    // Recent dates button
                    Button {
                        showRecentDates.toggle()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13))
                            .foregroundColor(settings.recentDates.isEmpty ? .secondary.opacity(0.4) : .dsAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.recentDates.isEmpty)
                    .help("Recent dates")
                    .popover(isPresented: $showRecentDates, arrowEdge: .bottom) {
                        recentDatesPopover
                    }
                }

                // Custom time picker (only shown when timeMode == .custom)
                if settings.timeMode == .custom {
                    Divider().frame(height: 20).padding(.horizontal, 8)
                    HStack(spacing: 6) {
                        Text("Time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }

                if dateHasError {
                    Text("Fix date first")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 4)
                }

                // Location button
                Divider().frame(height: 20).padding(.horizontal, 8)

                Button {
                    showLocationPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: settings.hasLocation
                              ? "mappin.circle.fill" : "mappin.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(settings.hasLocation
                                             ? Color(red: 0.85, green: 0.30, blue: 0.20)
                                             : Color.secondary)

                        if settings.hasLocation {
                            Text(settings.savedLocationLabel.isEmpty
                                 ? "Location set"
                                 : settings.savedLocationLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(red: 0.85, green: 0.30, blue: 0.20))                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 100, alignment: .leading)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(settings.hasLocation ? "Change location" : "Add location to EXIF")

                // Clear location X — separate from the main button so it doesn't trigger the map
                if settings.hasLocation {
                    Button {
                        settings.hasLocation = false
                        settings.savedLocationLabel = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear location")
                }

                if currentView != .drop {
                    Divider().frame(height: 20).padding(.horizontal, 12)
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
                }

                Divider().frame(height: 20).padding(.horizontal, 12)
            }

            // Settings gear
            Button {
                if currentView == .settings {
                    withAnimation(.easeInOut(duration: 0.2)) { currentView = previousView }
                } else {
                    previousView = currentView
                    withAnimation(.easeInOut(duration: 0.2)) { currentView = .settings }
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

    // MARK: - Recent dates popover

    private var recentDatesPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Dates")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            Divider()

            ForEach(settings.recentDates, id: \.self) { date in
                Button {
                    selectedDate = date
                    showRecentDates = false
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.dsAccent)
                            .frame(width: 16)
                        Text(formatRecentDate(date))
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.01))

                if date != settings.recentDates.last {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .frame(width: 200)
        .padding(.bottom, 8)
    }

    // MARK: - Drop view

    private var dropView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.dsNavy.opacity(0.04), Color.dsSky.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isTargetingDrop
                              ? Color.dsAccent.opacity(0.10)
                              : Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.dsMid.opacity(isTargetingDrop ? 0.25 : 0.08),
                                radius: isTargetingDrop ? 20 : 8, x: 0, y: 4)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isTargetingDrop ? Color.dsAccent : Color.dsMid.opacity(0.30),
                            style: StrokeStyle(lineWidth: 2, dash: isTargetingDrop ? [] : [10, 6])
                        )

                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.dsAccent.opacity(0.15), .dsMid.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 88, height: 88)
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(LinearGradient(
                                    colors: [.dsAccent, .dsMid],
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

                        Button { openFilePicker() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Browse Files")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 9)
                            .background(LinearGradient(colors: [.dsAccent, .dsMid],
                                                       startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                            .shadow(color: .dsAccent.opacity(0.35), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(44)

                    Color.clear.contentShape(Rectangle()).onTapGesture { openFilePicker() }
                }
                .frame(maxWidth: 480)
                .frame(height: 300)
                .onDrop(of: [.fileURL], isTargeted: $isTargetingDrop, perform: handleDrop)
                .animation(.easeInOut(duration: 0.15), value: isTargetingDrop)

                HStack(spacing: 16) {
                    ForEach(["Photos", "Videos", "Folders"], id: \.self) { label in
                        HStack(spacing: 5) {
                            Image(systemName: label == "Photos" ? "photo" :
                                             label == "Videos" ? "film" : "folder")
                                .font(.caption).foregroundColor(.dsAccent)
                            Text(label).font(.caption).foregroundStyle(.secondary)
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
                Button(allSelected ? "Deselect All" : "Select All") { toggleSelectAll() }
                    .buttonStyle(.plain)
                    .foregroundColor(.dsAccent)
                    .font(.subheadline.weight(.medium))

                Spacer()

                // Duplicate warning
                if duplicateCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("\(duplicateCount) already at this date")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.trailing, 8)
                }

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
                        FileRow(item: $item, targetDate: stampDate) {
                            selectedPreviewItem = item
                        }
                        Divider().padding(.leading, 56)
                    }
                }
            }

            Divider()

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
                    .background(LinearGradient(colors: [.dsAccent, .dsMid],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: .dsAccent.opacity(0.30), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(selectedItems.isEmpty || dateHasError)
                .opacity(selectedItems.isEmpty || dateHasError ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Confirm sheet

    private var confirmSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            VStack(spacing: 0) {
                confirmRow(icon: "doc.on.doc",    label: "Files",    value: "\(selectedItems.count)")
                Divider().padding(.leading, 44)
                confirmRow(icon: "calendar",       label: "New date", value: formattedStampDate())
                Divider().padding(.leading, 44)
                confirmRow(icon: "clock",          label: "Time",     value: formattedStampTime())
                Divider().padding(.leading, 44)
                confirmRow(icon: "square.grid.2x2",label: "Types",    value: fileTypeSummary())
                if duplicateCount > 0 {
                    Divider().padding(.leading, 44)
                    confirmRow(
                        icon: "exclamationmark.triangle",
                        label: "Already at this date",
                        value: "\(duplicateCount) file\(duplicateCount == 1 ? "" : "s")",
                        valueColor: .orange
                    )
                }
            }
            .padding(.vertical, 4)

            Divider()

            Group {
                if selectedItems.count < 8 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(selectedItems) { item in filePreviewRow(item: item) }
                    }
                    .padding(16)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(selectedItems) { item in filePreviewRow(item: item) }
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 160)
                }
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Options
            VStack(spacing: 0) {
                // Rename toggle + preview
                HStack(spacing: 12) {
                    Image(systemName: "pencil.line")
                        .foregroundColor(.dsAccent).frame(width: 20)
                        .padding(.leading, 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rename to date")
                            .font(.subheadline.weight(.medium))
                        Text("e.g. 1977-07-07_001.jpg")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    DSToggle(isOn: $renameOnStamp)
                        .padding(.trailing, 24)
                }
                .padding(.vertical, 11)

                // Rename preview — shown when toggle is on
                if renameOnStamp {
                    Divider().padding(.leading, 44)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(selectedItems.prefix(6).enumerated()), id: \.offset) { idx, item in
                                RenamePreviewRow(
                                    original: item.fileName,
                                    renamed: previewRename(item: item, index: idx + 1)
                                )
                            }
                            if selectedItems.count > 6 {
                                Text("+ \(selectedItems.count - 6) more…")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 22)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                    }
                    .frame(maxHeight: 120)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                }

                Divider().padding(.leading, 44)

                // Location summary row (read-only in confirm — set from title bar)
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(settings.hasLocation ? .dsPin : Color.secondary)
                        .frame(width: 20)
                        .padding(.leading, 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Location")
                            .font(.subheadline.weight(.medium))
                        Text(settings.hasLocation
                             ? (settings.savedLocationLabel.isEmpty ? "GPS coordinates set" : settings.savedLocationLabel)
                             : "None — set in toolbar to add GPS")
                            .font(.caption)
                            .foregroundColor(settings.hasLocation ? .dsPin : Color.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                }
                .padding(.vertical, 11)

                Divider().padding(.leading, 44)

                // Undo backup toggle
                HStack(spacing: 12) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundColor(.dsAccent).frame(width: 20)
                        .padding(.leading, 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Enable undo")
                            .font(.subheadline.weight(.medium))
                        Text("Saves .bak copies before modifying")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    DSToggle(isOn: $canUndo).padding(.trailing, 24)
                }
                .padding(.vertical, 11)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

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
                    .background(LinearGradient(colors: [.dsAccent, .dsMid],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
            }
            .padding(24)
        }
        .frame(width: 460)
    }

    private func confirmRow(icon: String, label: String, value: String,
                            valueColor: Color = .primary) -> some View {
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
                .foregroundColor(valueColor)
                .padding(.trailing, 24)
        }
        .padding(.vertical, 11)
    }

    private func filePreviewRow(item: ExifTool.FileItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.isVideo ? "film" : "photo")
                .foregroundStyle(item.isVideo ? Color.purple : Color.dsAccent)
                .font(.caption).frame(width: 16)
            Text(item.fileName)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if item.isDuplicate(of: stampDate) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.caption)
            }
        }
    }

    // MARK: - Results view

    private var resultsView: some View {
        VStack(spacing: 0) {
            let succeeded = results.filter { $0.success }.count
            let failed    = results.filter { !$0.success }.count

            HStack(spacing: 20) {
                if isProcessing {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Updating \(processedCount) of \(totalToProcess)…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    resultBadge(count: succeeded, label: "stamped",
                                icon: "checkmark.circle.fill", color: .green)
                    if failed > 0 {
                        resultBadge(count: failed, label: "failed",
                                    icon: "xmark.circle.fill", color: .red)
                    }
                }
                Spacer()
                Text("\(results.count) of \(totalToProcess) total")
                    .font(.subheadline).foregroundStyle(.secondary)
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
                // Show in Finder
                if !results.isEmpty && !isProcessing {
                    Button {
                        showInFinder()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                            Text("Show in Finder")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                // Undo
                if canUndo && !isProcessing && results.contains(where: { $0.backupURL != nil }) {
                    Button {
                        undoLastStamp()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo Stamp")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                }

                Spacer()

                Button {
                    resetToStart()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Start Over").fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(LinearGradient(colors: [.dsAccent, .dsMid],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func resultBadge(count: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text("\(count) \(label)").font(.subheadline.weight(.medium))
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
        let unique = newItems.filter { !existing.contains($0.url.path) }
        fileItems.append(contentsOf: unique)
        withAnimation(.easeInOut(duration: 0.2)) { currentView = .fileList }

        // Load current EXIF dates asynchronously
        for item in unique {
            guard let idx = fileItems.firstIndex(where: { $0.id == item.id }) else { continue }
            let url = item.url
            DispatchQueue.global(qos: .utility).async {
                let dateStr = ExifTool.readCurrentDate(file: url)
                DispatchQueue.main.async {
                    if let i = fileItems.firstIndex(where: { $0.url == url }) {
                        fileItems[i].currentExifDate = dateStr
                        fileItems[i].isLoadingDate = false
                    }
                }
            }
            _ = idx
        }
    }

    private func toggleSelectAll() {
        let v = !allSelected
        for i in fileItems.indices { fileItems[i].isSelected = v }
    }

    private func runUpdate() {
        let toProcess = selectedItems
        totalToProcess = toProcess.count
        processedCount = 0
        isProcessing = true
        results = []
        lastResults = []
        withAnimation { currentView = .results }

        let date = stampDate
        let doRename = renameOnStamp
        let doBackup = canUndo
        let coord = currentLocationCoord
        settings.addRecentDate(selectedDate)

        DispatchQueue.global(qos: .userInitiated).async {
            for (index, item) in toProcess.enumerated() {
                let r = ExifTool.updateDate(
                    file: item.url,
                    to: date,
                    rename: doRename,
                    renameIndex: index + 1,
                    location: coord,
                    createBackup: doBackup
                )
                DispatchQueue.main.async {
                    results.append(r)
                    lastResults.append(r)
                    processedCount += 1
                }
            }
            DispatchQueue.main.async {
                isProcessing = false
                // Clear location after stamp if setting is on
                if settings.clearLocationAfterStamp {
                    settings.hasLocation = false
                    settings.savedLocationLabel = ""
                }
            }
        }
    }

    private func undoLastStamp() {        let toUndo = lastResults
        DispatchQueue.global(qos: .userInitiated).async {
            let (restored, _) = ExifTool.undoStamp(results: toUndo)
            DispatchQueue.main.async {
                // Clear results and show a brief confirmation
                if restored > 0 {
                    results = []
                    lastResults = []
                    canUndo = false
                    resetToStart()
                }
            }
        }
    }

    private func showInFinder() {
        // Collect unique parent folders from successful results
        let folders = Set(results.filter { $0.success }.map {
            $0.file.deletingLastPathComponent()
        })
        for folder in folders {
            NSWorkspace.shared.open(folder)
        }
    }

    private func previewRename(item: ExifTool.FileItem, index: Int) -> String {
        let datePart = ExifTool.formatDateForFilename(stampDate)
        let seq = String(format: "%03d", index)
        return "\(datePart)_\(seq).\(item.url.pathExtension)"
    }

    private func resetToStart() {
        fileItems = []; results = []; isProcessing = false
        processedCount = 0; totalToProcess = 0
        withAnimation { currentView = .drop }
    }

    private func formattedStampDate() -> String {
        let f = DateFormatter(); f.dateStyle = .long
        return f.string(from: stampDate)
    }

    private func formattedStampTime() -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: stampDate)
    }

    private func fileTypeSummary() -> String {
        let imgs = selectedItems.filter { !$0.isVideo }.count
        let vids = selectedItems.filter { $0.isVideo }.count
        var p: [String] = []
        if imgs > 0 { p.append("\(imgs) photo\(imgs == 1 ? "" : "s")") }
        if vids > 0 { p.append("\(vids) video\(vids == 1 ? "" : "s")") }
        return p.joined(separator: ", ")
    }

    private func formatRecentDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - FileRow

struct FileRow: View {
    @Binding var item: ExifTool.FileItem
    let targetDate: Date
    var onPreview: (() -> Void)? = nil

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

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                if item.isLoadingDate {
                    Text("Reading…")
                        .font(.caption).foregroundStyle(.tertiary)
                } else if let d = item.currentExifDate {
                    HStack(spacing: 4) {
                        Text(d)
                            .font(.caption)
                            .foregroundStyle(item.isDuplicate(of: targetDate)
                                             ? Color.orange : Color.secondary)
                        if item.isDuplicate(of: targetDate) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9)).foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("No date set")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(item.url.deletingLastPathComponent().lastPathComponent)
                .font(.caption).foregroundStyle(.tertiary).lineLimit(1)

            // Info button — opens EXIF preview
            Button {
                onPreview?()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("View metadata")
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

// MARK: - RenamePreviewRow

struct RenamePreviewRow: View {
    let original: String
    let renamed: String

    var body: some View {
        HStack(spacing: 6) {
            Text(original)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.dsAccent)
            Text(renamed)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.dsAccent)
                .lineLimit(1)
        }
    }
}

#Preview {
    ContentView()
}
