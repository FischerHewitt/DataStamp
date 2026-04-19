import SwiftUI

struct SettingsView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sectionHeader("Appearance")
                appearanceSection

                Divider().padding(.horizontal, 20)

                sectionHeader("Text & Icon Size")
                uiScaleSection

                Divider().padding(.horizontal, 20)

                sectionHeader("Date Input")
                dateInputSection

                Divider().padding(.horizontal, 20)

                sectionHeader("Time")
                timeSection

                Divider().padding(.horizontal, 20)

                sectionHeader("Scanning")
                scanningSection

                Divider().padding(.horizontal, 20)

                sectionHeader("About")
                aboutSection
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Date Input

    private var dateInputSection: some View {
        VStack(spacing: 0) {
            ForEach(SettingsStore.DatePickerStyle.allCases) { style in
                let isLast = style == SettingsStore.DatePickerStyle.allCases.last
                settingsRow {
                    Button {
                        settings.datePickerStyle = style
                    } label: {
                        HStack(spacing: 14) {
                            settingsIcon(style.icon, color: settings.datePickerStyle == style ? .dsAccent : .dsMid)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.rawValue)
                                    .font(.subheadline.weight(.medium))
                                Text(styleDescription(style))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if settings.datePickerStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.dsAccent)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !isLast { Divider().padding(.leading, 66) }
            }
        }
    }

    private func styleDescription(_ style: SettingsStore.DatePickerStyle) -> String {
        switch style {
        case .compact:   return "Click to open a calendar popup"
        case .textField: return "Type a date like 07/07/1977"
        }
    }

    // MARK: - Time

    @State private var timeText: String = ""
    @State private var timeState: TimeFieldState = .valid
    @FocusState private var timeFocused: Bool

    private enum TimeFieldState { case valid, editing, invalid }

    private var timeSection: some View {
        VStack(spacing: 0) {

            // ── Default time row ──────────────────────────────────────────
            settingsRow {
                HStack(spacing: 14) {
                    settingsIcon("clock.badge.checkmark",
                                 color: settings.timeMode == .default_ ? .dsAccent : .dsMid)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeModeTitle(.default_))
                            .font(.subheadline.weight(.medium))
                        Text(timeModeDescription(.default_))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if settings.timeMode == .default_ {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.dsAccent).font(.system(size: 16))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { settings.timeMode = .default_ }
            }

            // ── Time input — visible when Default is selected ─────────────
            if settings.timeMode == .default_ {
                Divider().padding(.leading, 66)

                settingsRow {
                    HStack(spacing: 10) {
                        Color.clear.frame(width: 32, height: 1)   // indent

                        Text("Time")
                            .font(.subheadline).foregroundStyle(.secondary)

                        Spacer()

                        // HH:MM text field
                        HStack(spacing: 6) {
                            ZStack(alignment: .leading) {
                                if timeText.isEmpty {
                                    Text("HH:MM")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 8)
                                }
                                TextField("", text: $timeText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .focused($timeFocused)
                                    .frame(width: 72)
                                    .onAppear { syncTimeText() }
                                    .onChange(of: timeText) { _ in
                                        // Live: go editing, turn green if parseable
                                        liveValidateTime(timeText)
                                    }
                                    .onChange(of: timeFocused) { focused in
                                        if focused {
                                            if timeState == .valid { timeState = .editing }
                                        } else {
                                            commitTimeText()
                                        }
                                    }
                                    .onSubmit { commitTimeText() }
                            }
                            .background(timeBorderBackground)

                            // Status icon
                            timeStatusIcon

                            // AM / PM toggle
                            HStack(spacing: 0) {
                                amPmButton("AM", isSelected: settings.defaultTimeIsAM)
                                amPmButton("PM", isSelected: !settings.defaultTimeIsAM)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }

                // ── Timezone picker ───────────────────────────────────────
                Divider().padding(.leading, 66)

                settingsRow {
                    HStack(spacing: 14) {
                        Color.clear.frame(width: 32, height: 1)

                        Text("Timezone")
                            .font(.subheadline).foregroundStyle(.secondary)

                        Spacer()

                        Picker("", selection: $settings.defaultTimezone) {
                            ForEach(SettingsStore.commonTimezones, id: \.identifier) { tz in
                                Text(tz.label).tag(tz.identifier)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }
            }

            Divider().padding(.leading, 66)

            // ── Custom time row ───────────────────────────────────────────
            settingsRow {
                HStack(spacing: 14) {
                    settingsIcon(SettingsStore.TimeMode.custom.icon,
                                 color: settings.timeMode == .custom ? .dsAccent : .dsMid)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeModeTitle(.custom))
                            .font(.subheadline.weight(.medium))
                        Text(timeModeDescription(.custom))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if settings.timeMode == .custom {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.dsAccent).font(.system(size: 16))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { settings.timeMode = .custom }
            }
        }
    }

    // MARK: - Time field helpers

    private var timeBorderColor: Color {
        switch timeState {
        case .valid:   return .green
        case .editing: return .dsAccent
        case .invalid: return .red
        }
    }

    private var timeBorderBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(timeState == .invalid
                  ? Color.red.opacity(0.07)
                  : timeState == .valid
                      ? Color.green.opacity(0.06)
                      : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(timeBorderColor, lineWidth: 1.5)
            )
    }

    @ViewBuilder
    private var timeStatusIcon: some View {
        switch timeState {
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green).font(.system(size: 13))
        case .editing:
            EmptyView()
        case .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red).font(.system(size: 13))
        }
    }

    private func amPmButton(_ label: String, isSelected: Bool) -> some View {
        let isAM = label == "AM"
        return Button {
            settings.defaultTimeIsAM = isAM
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected
                             ? LinearGradient(colors: [.dsAccent, .dsMid],
                                              startPoint: .leading, endPoint: .trailing)
                             : LinearGradient(colors: [Color.clear, Color.clear],
                                              startPoint: .leading, endPoint: .trailing))
        }
        .buttonStyle(.plain)
    }

    private func syncTimeText() {
        let h = settings.defaultTimeHour == 0 ? 12 :
                settings.defaultTimeHour > 12 ? settings.defaultTimeHour - 12 :
                settings.defaultTimeHour
        timeText = String(format: "%d:%02d", h, settings.defaultTimeMinute)
        timeState = .valid
    }

    private func liveValidateTime(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { timeState = .editing; return }
        if parseTime(trimmed) != nil {
            timeState = .valid
        } else {
            timeState = trimmed.count >= 3 ? .invalid : .editing
        }
    }

    private func commitTimeText() {
        let trimmed = timeText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { timeState = .invalid; return }
        if let (h, m) = parseTime(trimmed) {
            settings.defaultTimeHour   = h
            settings.defaultTimeMinute = m
            timeText = String(format: "%d:%02d", h == 0 ? 12 : h > 12 ? h - 12 : h, m)
            timeState = .valid
        } else {
            timeState = .invalid
        }
    }

    /// Parse "H:MM" or "HH:MM" in 12-hour format. Returns (hour 1-12, minute).
    private func parseTime(_ text: String) -> (Int, Int)? {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 1, h <= 12, m >= 0, m <= 59
        else { return nil }
        return (h, m)
    }

    private func timeModeTitle(_ mode: SettingsStore.TimeMode) -> String {
        switch mode {
        case .default_: return "Default time"
        case .custom:   return "Custom time per session"
        }
    }

    private func timeModeDescription(_ mode: SettingsStore.TimeMode) -> String {
        switch mode {
        case .default_: return "Always stamp at the configured time (default 7:00 AM PST)"
        case .custom:   return "Show a time picker in the toolbar each session"
        }
    }

    // MARK: - UI Scale

    private var uiScaleSection: some View {
        settingsRow {
            HStack(spacing: 14) {
                settingsIcon("textformat.size", color: .dsMid)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Text & Icon Size")
                        .font(.subheadline.weight(.medium))
                    Text(scaleLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    // Decrease
                    Button {
                        settings.uiScale = max(0.8, (settings.uiScale - 0.1).rounded(toPlaces: 1))
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 18))
                            .foregroundColor(settings.uiScale <= 0.8 ? .secondary.opacity(0.4) : .dsAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.uiScale <= 0.8)

                    // Visual scale bar
                    HStack(spacing: 3) {
                        ForEach(scaleSteps, id: \.self) { step in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(step <= settings.uiScale ? Color.dsAccent : Color(NSColor.separatorColor))
                                .frame(width: 6, height: step <= settings.uiScale ? 14 : 8)
                                .animation(.easeInOut(duration: 0.15), value: settings.uiScale)
                        }
                    }

                    // Increase
                    Button {
                        settings.uiScale = min(1.4, (settings.uiScale + 0.1).rounded(toPlaces: 1))
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundColor(settings.uiScale >= 1.4 ? .secondary.opacity(0.4) : .dsAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.uiScale >= 1.4)

                    // Reset
                    Button {
                        settings.uiScale = 1.0
                    } label: {
                        Text("Reset")
                            .font(.caption)
                            .foregroundColor(settings.uiScale == 1.0 ? .secondary.opacity(0.4) : .dsAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.uiScale == 1.0)
                }
            }
        }
    }

    private var scaleSteps: [Double] { [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4] }

    private var scaleLabel: String {
        switch settings.uiScale {
        case ..<0.85: return "Extra Small"
        case ..<0.95: return "Small"
        case ..<1.05: return "Default"
        case ..<1.15: return "Large"
        case ..<1.25: return "Extra Large"
        case ..<1.35: return "2× Large"
        default:      return "3× Large"
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(SettingsStore.AppearanceMode.allCases) { mode in
                    AppearanceTile(
                        mode: mode,
                        isSelected: settings.appearanceMode == mode
                    ) {
                        settings.appearanceMode = mode
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Scanning

    private var scanningSection: some View {
        VStack(spacing: 0) {
            settingsRow {
                HStack(spacing: 14) {
                    settingsIcon("folder.badge.gearshape", color: .dsMid)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include Subfolders")
                            .font(.subheadline.weight(.medium))
                        Text("Scan nested folders when a folder is dropped")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    DSToggle(isOn: $settings.includeSubfolders)
                }
            }

            Divider().padding(.leading, 66)

            settingsRow {
                HStack(spacing: 14) {
                    settingsIcon("mappin.slash", color: .dsMid)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear location after each stamp")
                            .font(.subheadline.weight(.medium))
                        Text("Resets the pinned location after every stamp run")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    DSToggle(isOn: $settings.clearLocationAfterStamp)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(spacing: 0) {
            settingsRow {
                HStack(spacing: 14) {
                    // App icon thumbnail
                    Image("AppIconPreview")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("PhotoStamp")
                            .font(.subheadline.weight(.semibold))
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            Divider().padding(.leading, 74)

            settingsRow {
                HStack(spacing: 14) {
                    settingsIcon("hammer.fill", color: .dsAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Built with exiftool \(exiftoolVersion)")
                            .font(.subheadline.weight(.medium))
                        Text("Phil Harvey's metadata engine")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            Divider().padding(.leading, 74)

            settingsRow {
                HStack(spacing: 14) {
                    settingsIcon("envelope", color: .dsAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Source Code")
                            .font(.subheadline.weight(.medium))
                        Text("GitHub coming soon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(Color(NSColor.controlBackgroundColor))
    }

    private func settingsIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var exiftoolVersion: String {
        let path = ExifTool.bundledExiftoolPath()
        let (out, _, _) = ExifTool.runExiftool(args: ["-ver"])
        let v = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? "13.55" : v
    }
}

// MARK: - Appearance Tile

struct AppearanceTile: View {
    let mode: SettingsStore.AppearanceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Preview swatch
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(swatchBackground)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.dsAccent : Color(NSColor.separatorColor),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )

                    Image(systemName: mode.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(swatchForeground)
                }

                HStack(spacing: 5) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.dsAccent)
                    }
                    Text(mode.rawValue)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.dsAccent : Color.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var swatchBackground: Color {
        switch mode {
        case .system: return Color(NSColor.controlBackgroundColor)
        case .light:  return Color.white
        case .dark:   return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    private var swatchForeground: Color {
        switch mode {
        case .system: return Color.primary
        case .light:  return Color(red: 0.2, green: 0.2, blue: 0.2)
        case .dark:   return Color.white
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 480)
}

// MARK: - Helpers

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - DSToggle

struct DSToggle: View {
    @Binding var isOn: Bool

    private let width: CGFloat  = 44
    private let height: CGFloat = 26
    private let knobSize: CGFloat = 20

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // Track
            Capsule()
                .fill(isOn
                      ? LinearGradient(colors: [.dsAccent, .dsMid],
                                       startPoint: .leading, endPoint: .trailing)
                      : LinearGradient(colors: [Color(NSColor.separatorColor),
                                                Color(NSColor.separatorColor)],
                                       startPoint: .leading, endPoint: .trailing))
                .frame(width: width, height: height)

            // Knob — always white with a shadow so it pops on any background
            Circle()
                .fill(Color.white)
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                .padding(3)
        }
        .frame(width: width, height: height)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isOn)
        .onTapGesture { isOn.toggle() }
    }
}

#Preview {
    SettingsView()
        .frame(width: 480)
}
