import SwiftUI

class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    @AppStorage("includeSubfolders") var includeSubfolders: Bool = false
    @AppStorage("appearanceMode")    var appearanceMode: AppearanceMode = .system
    @AppStorage("datePickerStyle")   var datePickerStyle: DatePickerStyle = .compact
    @AppStorage("uiScale")           var uiScale: Double = 1.0  // 0.8 – 1.4

    // Time settings
    @AppStorage("timeMode")          var timeMode: TimeMode = .default_
    @AppStorage("defaultTimeHour")   var defaultTimeHour: Int = 7      // 12-hour value paired with defaultTimeIsAM
    @AppStorage("defaultTimeMinute") var defaultTimeMinute: Int = 0
    @AppStorage("defaultTimeIsAM")   var defaultTimeIsAM: Bool = true
    @AppStorage("defaultTimezone")   var defaultTimezone: String = "America/Los_Angeles"

    // Location — persisted across sessions
    @AppStorage("savedLocationLat")   var savedLocationLat: Double = 0
    @AppStorage("savedLocationLon")   var savedLocationLon: Double = 0
    @AppStorage("savedLocationLabel") var savedLocationLabel: String = ""
    @AppStorage("hasLocation")        var hasLocation: Bool = false
    @AppStorage("clearLocationAfterStamp") var clearLocationAfterStamp: Bool = false

    // Recent dates — stored as comma-separated ISO strings
    @AppStorage("recentDates")       private var recentDatesRaw: String = ""

    // MARK: - Initialisers

    /// Convenience initialiser used by the shared singleton — backed by `UserDefaults.standard`.
    convenience init() {
        self.init(defaults: .standard)
    }

    /// Designated initialiser that wires every `@AppStorage` property wrapper to the
    /// supplied `UserDefaults` suite.  Pass a custom suite in tests so that reads and
    /// writes are isolated from the real app preferences.
    init(defaults: UserDefaults) {
        _includeSubfolders      = AppStorage(wrappedValue: false,                    "includeSubfolders",      store: defaults)
        _appearanceMode         = AppStorage(wrappedValue: .system,                  "appearanceMode",         store: defaults)
        _datePickerStyle        = AppStorage(wrappedValue: .compact,                 "datePickerStyle",        store: defaults)
        _uiScale                = AppStorage(wrappedValue: 1.0,                      "uiScale",                store: defaults)
        _timeMode               = AppStorage(wrappedValue: .default_,                "timeMode",               store: defaults)
        _defaultTimeHour        = AppStorage(wrappedValue: 7,                        "defaultTimeHour",        store: defaults)
        _defaultTimeMinute      = AppStorage(wrappedValue: 0,                        "defaultTimeMinute",      store: defaults)
        _defaultTimeIsAM        = AppStorage(wrappedValue: true,                     "defaultTimeIsAM",        store: defaults)
        _defaultTimezone        = AppStorage(wrappedValue: "America/Los_Angeles",    "defaultTimezone",        store: defaults)
        _savedLocationLat       = AppStorage(wrappedValue: 0,                        "savedLocationLat",       store: defaults)
        _savedLocationLon       = AppStorage(wrappedValue: 0,                        "savedLocationLon",       store: defaults)
        _savedLocationLabel     = AppStorage(wrappedValue: "",                       "savedLocationLabel",     store: defaults)
        _hasLocation            = AppStorage(wrappedValue: false,                    "hasLocation",            store: defaults)
        _clearLocationAfterStamp = AppStorage(wrappedValue: false,                   "clearLocationAfterStamp", store: defaults)
        _recentDatesRaw         = AppStorage(wrappedValue: "",                       "recentDates",            store: defaults)
    }

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
        cal.timeZone = TimeZone(identifier: defaultTimezone) ?? TimeZone.current

        switch timeMode {
        case .default_:
            // Convert 12h input to 24h
            var hour24 = defaultTimeHour % 12
            if !defaultTimeIsAM { hour24 += 12 }
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour   = hour24
            comps.minute = defaultTimeMinute
            comps.second = 0
            comps.timeZone = cal.timeZone
            return cal.date(from: comps) ?? date

        case .custom:
            guard let t = customTime else { return date }
            let timeComps = cal.dateComponents([.hour, .minute], from: t)
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour   = timeComps.hour
            comps.minute = timeComps.minute
            comps.second = 0
            comps.timeZone = cal.timeZone
            return cal.date(from: comps) ?? date
        }
    }

    /// Common timezones for the picker.
    static let commonTimezones: [(label: String, identifier: String)] = [
        ("PST / PDT — Los Angeles",  "America/Los_Angeles"),
        ("MST / MDT — Denver",       "America/Denver"),
        ("CST / CDT — Chicago",      "America/Chicago"),
        ("EST / EDT — New York",     "America/New_York"),
        ("GMT — London",             "Europe/London"),
        ("CET — Paris / Berlin",     "Europe/Paris"),
        ("IST — Mumbai",             "Asia/Kolkata"),
        ("CST — Shanghai",           "Asia/Shanghai"),
        ("JST — Tokyo",              "Asia/Tokyo"),
        ("AEST — Sydney",            "Australia/Sydney"),
    ]

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
