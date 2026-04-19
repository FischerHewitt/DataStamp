import SwiftUI

/// Persists user preferences via UserDefaults.
/// Shared as an @Observable so any view can read/write it.
class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    @AppStorage("includeSubfolders") var includeSubfolders: Bool = false
    @AppStorage("appearanceMode")    var appearanceMode: AppearanceMode = .system
    @AppStorage("datePickerStyle")   var datePickerStyle: DatePickerStyle = .compact

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light  = "Light"
        case dark   = "Dark"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light:  return "sun.max"
            case .dark:   return "moon"
            }
        }
    }

    enum DatePickerStyle: String, CaseIterable, Identifiable {
        case compact   = "Calendar"
        case textField = "Type Date"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .compact:   return "calendar"
            case .textField: return "keyboard"
            }
        }
    }
}
