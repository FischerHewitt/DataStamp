import SwiftUI

struct SettingsView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sectionHeader("Appearance")
                appearanceSection

                Divider().padding(.horizontal, 20)

                sectionHeader("Date Input")
                dateInputSection

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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Custom toggle so the knob stays visible on the blue track
                    DSToggle(isOn: $settings.includeSubfolders)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.dsAccent, .dsMid],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "photo.badge.arrow.down.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .semibold))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DataStamp")
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

// MARK: - DSToggle
// Custom toggle that keeps the white knob visible against the blue track.

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
