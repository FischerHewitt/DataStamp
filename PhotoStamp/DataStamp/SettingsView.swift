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
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(styleDescription(style))
                    .accessibilityLabel("\(style.rawValue) date input")
                    .accessibilityValue(settings.datePickerStyle == style ? "Selected" : "Not selected")
                    .accessibilityHint(styleDescription(style))
                    .accessibilityIdentifier(style == .textField ? "dateStyleTextField" : "")
                }
                if !isLast { Divider().padding(.leading, 66) }
            }
        }
    }

    private func styleDescription(_ style: SettingsStore.DatePickerStyle) -> String {
        switch style {
        case .compact:   return "Open a calendar popup"
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

            settingsRow { timeModeRow(.default_) }

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
                            TextField("Time", text: $timeText, prompt: Text("HH:MM"))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .focused($timeFocused)
                                .frame(width: 72)
                                .onAppear { syncTimeText() }
                                .onChange(of: timeText) { _ in
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
                                .accessibilityLabel("Default time")
                                .accessibilityValue(timeText.isEmpty ? "Empty" : "\(timeText), \(timeStateDescription)")
                                .accessibilityHint("Enter a time from 1:00 to 12:59.")
                            .background(timeBorderBackground)

                            // Status icon
                            timeStatusIcon

                            // AM / PM toggle
                            Picker("Time Period", selection: $settings.defaultTimeIsAM) {
                                Text("AM").tag(true)
                                Text("PM").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 88)
                            .accessibilityLabel("Time period")
                        }
                    }
                }

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
                        .accessibilityLabel("Default timezone")
                    }
                }
            }

            Divider().padding(.leading, 66)

            settingsRow { timeModeRow(.custom) }
        }
    }

    private func timeModeRow(_ mode: SettingsStore.TimeMode) -> some View {
        Button {
            settings.timeMode = mode
        } label: {
            HStack(spacing: 14) {
                settingsIcon(mode.icon, color: settings.timeMode == mode ? .dsAccent : .dsMid)
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeModeTitle(mode))
                        .font(.subheadline.weight(.medium))
                    Text(timeModeDescription(mode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if settings.timeMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.dsAccent)
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(timeModeDescription(mode))
        .accessibilityLabel(timeModeTitle(mode))
        .accessibilityValue(settings.timeMode == mode ? "Selected" : "Not selected")
        .accessibilityHint(timeModeDescription(mode))
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
                .accessibilityHidden(true)
        case .editing:
            EmptyView()
        case .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red).font(.system(size: 13))
                .accessibilityHidden(true)
        }
    }

    private var timeStateDescription: String {
        switch timeState {
        case .valid: return "Valid"
        case .editing: return "Editing"
        case .invalid: return "Invalid"
        }
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
        case .default_: return "Always stamp at the configured time (default 7:00 AM Pacific Time)"
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

                HStack(spacing: 10) {
                    Slider(value: uiScaleBinding, in: 0.8...1.4, step: 0.1)
                        .frame(width: 150)
                        .accessibilityLabel("Text and icon size")
                        .accessibilityValue(scaleLabel)

                    Text("\(Int((settings.uiScale * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                        .accessibilityHidden(true)

                    Button {
                        settings.uiScale = 1.0
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 18))
                            .foregroundColor(settings.uiScale == 1.0 ? .secondary.opacity(0.4) : .dsAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.uiScale == 1.0)
                    .help("Reset size")
                    .accessibilityLabel("Reset text and icon size")
                }
            }
        }
    }

    private var uiScaleBinding: Binding<Double> {
        Binding(
            get: { settings.uiScale },
            set: { settings.uiScale = $0.rounded(toPlaces: 1) }
        )
    }

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
                Toggle(isOn: $settings.includeSubfolders) {
                    HStack(spacing: 14) {
                        settingsIcon("folder.badge.gearshape", color: .dsMid)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include Subfolders")
                                .font(.subheadline.weight(.medium))
                            Text("Scan nested folders when a folder is dropped")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .toggleStyle(.switch)
                .tint(.dsAccent)
                .accessibilityHint("Scan nested folders when a folder is dropped")
            }

            Divider().padding(.leading, 66)

            settingsRow {
                Toggle(isOn: $settings.clearLocationAfterStamp) {
                    HStack(spacing: 14) {
                        settingsIcon("mappin.slash", color: .dsMid)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear location after each stamp")
                                .font(.subheadline.weight(.medium))
                            Text("Resets the pinned location after every stamp run")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .toggleStyle(.switch)
                .tint(.dsAccent)
                .accessibilityHint("Resets the pinned location after every stamp run")
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
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ImageStamp")
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
                        Text("Built with ImageIO & AVFoundation")
                            .font(.subheadline.weight(.medium))
                        Text("Apple's native metadata frameworks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            Divider().padding(.leading, 74)

            // Support link
            settingsRow {
                Link(destination: URL(string: "https://fischerhewitt.github.io/DataStamp")!) {
                    HStack(spacing: 14) {
                        settingsIcon("questionmark.circle", color: .dsAccent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Support & Help")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            Text("fischerhewitt.github.io/DataStamp")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .help("Open Support and Help")
                .accessibilityHint("Opens in your default browser")
            }

            Divider().padding(.leading, 74)

            // Privacy policy link
            settingsRow {
                Link(destination: URL(string: "https://fischerhewitt.github.io/DataStamp#privacy")!) {
                    HStack(spacing: 14) {
                        settingsIcon("lock.shield", color: .dsAccent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Policy")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            Text("No data collected — everything stays on your Mac")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .help("Open Privacy Policy")
                .accessibilityHint("Opens in your default browser")
            }

            Divider().padding(.leading, 74)

            // Contact
            settingsRow {
                Link(destination: URL(string: "mailto:fischerhewitt@gmail.com")!) {
                    HStack(spacing: 14) {
                        settingsIcon("envelope", color: .dsAccent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contact Support")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            Text("fischerhewitt@gmail.com")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .help("Email support")
                .accessibilityHint("Opens a new email message")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
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
        .accessibilityHidden(true)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mode.rawValue) appearance")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Use \(mode.rawValue.lowercased()) appearance")
        .help("\(mode.rawValue) appearance")
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
