import SwiftUI

class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    @AppStorage("includeSubfolders") var includeSubfolders: Bool = false
    @AppStorage("appearanceMode")    var appearanceMode: AppearanceMode = .system
    @AppStorage("datePickerStyle")   var datePickerStyle: DatePickerStyle = .compact

    // Time settings
    @AppStorage("timeMode")          var timeMode: TimeMode = .default_
    @AppStorage("defaultTimeHour")   var defaultTimeHour: Int = 7      // 7:00 AM
    @AppStorage("defaultTimeMinute") var defaultTimeMinute: Int = 0

    // Recent dates — stored as comma-separated ISO strings
    @AppStorage("recentDates")       private var recentDatesRaw: String = ""

    // MARK: - Recent dates

    var recentDates: [Date] {
        get {
            recentDatesRaw
                .split(separator: ",")
                .compactMap { Double($0) }
                .map { Date(timeIntervalSince1970: $0) }
        }
    }

    func addRecentDate(_ date: Date) {
        var dates = recentDates.filter {
            // Remove duplicates on same calendar day
            !Calendar.current.isDate($0, inSameDayAs: date)
        }
        dates.insert(date, at: 0)
        let kept = Array(dates.prefix(5))
        recentDatesRaw = kept.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
    }

    // MARK: - Computed time helpers

    /// Returns a Date combining the given calendar date with the configured time.
    func applyTime(to date: Date, customTime: Date? = nil) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current

        switch timeMode {
        case .default_:
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour   = defaultTimeHour
            comps.minute = defaultTimeMinute
            comps.second = 0
            return cal.date(from: comps) ?? date

        case .custom:
            guard let t = customTime else { return date }
            let timeComps = cal.dateComponents([.hour, .minute], from: t)
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour   = timeComps.hour
            comps.minute = timeComps.minute
            comps.second = 0
            return cal.date(from: comps) ?? date
        }
    }

    // MARK: - Enums

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

    enum TimeMode: String, CaseIterable, Identifiable {
        case default_ = "Default"
        case custom   = "Custom"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .default_: return "clock"
            case .custom:   return "clock.badge.checkmark"
            }
        }
    }
}
