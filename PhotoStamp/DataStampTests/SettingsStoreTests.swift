import Testing
import SwiftCheck
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5

@Suite("SettingsStore Persistence", .serialized)
struct SettingsStoreTests {

    // MARK: - Helpers

    /// Creates a unique UserDefaults suite name and returns both the name and the suite.
    private func makeDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        return (suiteName, defaults)
    }

    /// Builds a Date for a specific calendar day at noon UTC.
    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    // MARK: - Requirement 10.1: uiScale persists

    @Test("uiScale written by one SettingsStore instance is read back by a second instance on the same suite")
    func uiScalePersists() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)
        store1.uiScale = 1.3

        // Force UserDefaults to flush to disk before reading back
        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.uiScale == 1.3,
                "Expected uiScale 1.3 to persist across SettingsStore instances on the same suite")
    }

    @Test("uiScale default value is 1.0 on a fresh suite")
    func uiScaleDefaultValue() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        #expect(store.uiScale == 1.0,
                "Expected default uiScale to be 1.0")
    }

    // MARK: - Requirement 10.2: appearanceMode persists

    @Test("appearanceMode .dark persists and raw value is 'Dark' when read back from a second instance")
    func appearanceModePersists() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)
        store1.appearanceMode = .dark

        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.appearanceMode == .dark,
                "Expected appearanceMode .dark to persist across SettingsStore instances")
        #expect(store2.appearanceMode.rawValue == "Dark",
                "Expected raw value of .dark to be 'Dark'")
    }

    @Test("appearanceMode .light persists across instances")
    func appearanceModeLightPersists() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)
        store1.appearanceMode = .light

        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.appearanceMode == .light,
                "Expected appearanceMode .light to persist across SettingsStore instances")
        #expect(store2.appearanceMode.rawValue == "Light",
                "Expected raw value of .light to be 'Light'")
    }

    @Test("appearanceMode .system persists across instances")
    func appearanceModeSystemPersists() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)
        store1.appearanceMode = .system

        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.appearanceMode == .system,
                "Expected appearanceMode .system to persist across SettingsStore instances")
        #expect(store2.appearanceMode.rawValue == "System",
                "Expected raw value of .system to be 'System'")
    }

    // MARK: - Requirement 10.3: hasLocation / savedLocationLat / savedLocationLon persist

    @Test("hasLocation, savedLocationLat, and savedLocationLon persist across SettingsStore instances")
    func locationPersists() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)
        store1.hasLocation = true
        store1.savedLocationLat = 37.7749
        store1.savedLocationLon = -122.4194

        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.hasLocation == true,
                "Expected hasLocation true to persist across SettingsStore instances")
        #expect(store2.savedLocationLat == 37.7749,
                "Expected savedLocationLat 37.7749 to persist across SettingsStore instances")
        #expect(store2.savedLocationLon == -122.4194,
                "Expected savedLocationLon -122.4194 to persist across SettingsStore instances")
    }

    @Test("hasLocation false persists across instances")
    func locationFalsePersists() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)
        store1.hasLocation = true
        store1.savedLocationLat = 51.5074
        store1.savedLocationLon = -0.1278

        defaults.synchronize()

        // Now clear the location
        store1.hasLocation = false

        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.hasLocation == false,
                "Expected hasLocation false to persist after being cleared")
    }

    @Test("negative latitude and longitude persist correctly")
    func negativeCoordinatesPersist() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)
        store1.hasLocation = true
        store1.savedLocationLat = -33.8688   // Sydney latitude
        store1.savedLocationLon = 151.2093   // Sydney longitude

        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.savedLocationLat == -33.8688,
                "Expected negative latitude to persist correctly")
        #expect(store2.savedLocationLon == 151.2093,
                "Expected positive longitude to persist correctly")
    }

    // MARK: - Requirement 10.4: recentDates prepend order and max entries

    @Test("recentDates are prepended — newest date appears first")
    func recentDatesPrependOrder() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        let d1 = date(year: 2024, month: 1, day: 1)
        let d2 = date(year: 2024, month: 2, day: 1)
        let d3 = date(year: 2024, month: 3, day: 1)

        store.addRecentDate(d1)
        store.addRecentDate(d2)
        store.addRecentDate(d3)

        let recent = store.recentDates
        #expect(recent.count >= 3,
                "Expected at least 3 recent dates after adding 3 distinct dates")

        // d3 was added last, so it should be first (prepend order)
        let cal = Calendar.current
        #expect(cal.isDate(recent[0], inSameDayAs: d3),
                "Expected most recently added date (d3) to be at index 0")
        #expect(cal.isDate(recent[1], inSameDayAs: d2),
                "Expected second most recently added date (d2) to be at index 1")
        #expect(cal.isDate(recent[2], inSameDayAs: d1),
                "Expected first added date (d1) to be at index 2")
    }

    @Test("recentDates persists prepend order across a second SettingsStore instance")
    func recentDatesPrependOrderPersistsAcrossInstances() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store1 = SettingsStore(defaults: defaults)

        let d1 = date(year: 2023, month: 6, day: 1)
        let d2 = date(year: 2023, month: 7, day: 1)

        store1.addRecentDate(d1)
        store1.addRecentDate(d2)

        defaults.synchronize()

        let store2 = SettingsStore(defaults: defaults)
        let recent = store2.recentDates

        #expect(recent.count >= 2,
                "Expected at least 2 recent dates after adding 2 distinct dates")

        let cal = Calendar.current
        #expect(cal.isDate(recent[0], inSameDayAs: d2),
                "Expected most recently added date (d2) to be at index 0 after reading from second instance")
        #expect(cal.isDate(recent[1], inSameDayAs: d1),
                "Expected first added date (d1) to be at index 1 after reading from second instance")
    }

    @Test("recentDates does not exceed the maximum number of entries")
    func recentDatesMaxEntries() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        // Add more dates than the maximum allowed
        // The implementation uses prefix(5), so we add 7 distinct dates
        for i in 1...7 {
            let d = date(year: 2024, month: i > 6 ? 6 : i, day: i > 6 ? i : 1)
            store.addRecentDate(d)
        }

        let recent = store.recentDates
        // The implementation caps at 5 entries
        #expect(recent.count <= 5,
                "Expected recentDates to be capped at the maximum (5), got \(recent.count)")
    }

    @Test("recentDates deduplicates entries on the same calendar day")
    func recentDatesDeduplicate() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        // Add the same calendar day twice (different times)
        let d1 = date(year: 2024, month: 5, day: 10)
        var comps = DateComponents()
        comps.year = 2024; comps.month = 5; comps.day = 10
        comps.hour = 18; comps.minute = 30; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        let d1b = Calendar(identifier: .gregorian).date(from: comps)!

        store.addRecentDate(d1)
        store.addRecentDate(d1b)

        let recent = store.recentDates
        #expect(recent.count == 1,
                "Expected only 1 entry when the same calendar day is added twice, got \(recent.count)")
    }

    // MARK: - Requirement 10.5: applyTime with timeMode == .default_

    @Test("applyTime with timeMode .default_ returns a Date with the configured hour and minute (AM)")
    func applyTimeDefaultModeAM() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.timeMode = .default_
        store.defaultTimeHour = 7       // 7 AM in 12-hour format
        store.defaultTimeMinute = 30
        store.defaultTimeIsAM = true
        store.defaultTimezone = "UTC"

        let inputDate = date(year: 2024, month: 6, day: 15)
        let result = store.applyTime(to: inputDate)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.hour, .minute], from: result)

        #expect(comps.hour == 7,
                "Expected hour 7 (AM), got \(comps.hour as Any)")
        #expect(comps.minute == 30,
                "Expected minute 30, got \(comps.minute as Any)")
    }

    @Test("applyTime with timeMode .default_ returns a Date with the configured hour and minute (PM)")
    func applyTimeDefaultModePM() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.timeMode = .default_
        store.defaultTimeHour = 3       // 3 PM → 15:00 in 24-hour
        store.defaultTimeMinute = 45
        store.defaultTimeIsAM = false
        store.defaultTimezone = "UTC"

        let inputDate = date(year: 2024, month: 6, day: 15)
        let result = store.applyTime(to: inputDate)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.hour, .minute], from: result)

        #expect(comps.hour == 15,
                "Expected hour 15 (3 PM in 24h), got \(comps.hour as Any)")
        #expect(comps.minute == 45,
                "Expected minute 45, got \(comps.minute as Any)")
    }

    @Test("applyTime with timeMode .default_ returns a Date with hour 0 for 12 AM (midnight)")
    func applyTimeDefaultModeMidnight() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.timeMode = .default_
        store.defaultTimeHour = 12      // 12 AM → 0:00 in 24-hour
        store.defaultTimeMinute = 0
        store.defaultTimeIsAM = true
        store.defaultTimezone = "UTC"

        let inputDate = date(year: 2024, month: 6, day: 15)
        let result = store.applyTime(to: inputDate)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.hour, .minute], from: result)

        // 12 AM → hour24 = 12 % 12 = 0
        #expect(comps.hour == 0,
                "Expected hour 0 for 12 AM (midnight), got \(comps.hour as Any)")
        #expect(comps.minute == 0,
                "Expected minute 0, got \(comps.minute as Any)")
    }

    @Test("applyTime with timeMode .default_ returns a Date with hour 12 for 12 PM (noon)")
    func applyTimeDefaultModeNoon() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.timeMode = .default_
        store.defaultTimeHour = 12      // 12 PM → 12:00 in 24-hour
        store.defaultTimeMinute = 0
        store.defaultTimeIsAM = false
        store.defaultTimezone = "UTC"

        let inputDate = date(year: 2024, month: 6, day: 15)
        let result = store.applyTime(to: inputDate)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.hour, .minute], from: result)

        // 12 PM → hour24 = (12 % 12) + 12 = 12
        #expect(comps.hour == 12,
                "Expected hour 12 for 12 PM (noon), got \(comps.hour as Any)")
        #expect(comps.minute == 0,
                "Expected minute 0, got \(comps.minute as Any)")
    }

    @Test("applyTime with timeMode .default_ preserves the calendar date of the input")
    func applyTimeDefaultModePreservesDate() {
        let (suiteName, defaults) = makeDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.timeMode = .default_
        store.defaultTimeHour = 9
        store.defaultTimeMinute = 15
        store.defaultTimeIsAM = true
        store.defaultTimezone = "UTC"

        let inputDate = date(year: 1977, month: 7, day: 7)
        let result = store.applyTime(to: inputDate)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: result)

        #expect(comps.year == 1977,
                "Expected year 1977 to be preserved, got \(comps.year as Any)")
        #expect(comps.month == 7,
                "Expected month 7 to be preserved, got \(comps.month as Any)")
        #expect(comps.day == 7,
                "Expected day 7 to be preserved, got \(comps.day as Any)")
        #expect(comps.hour == 9,
                "Expected hour 9, got \(comps.hour as Any)")
        #expect(comps.minute == 15,
                "Expected minute 15, got \(comps.minute as Any)")
    }
}

// MARK: - Property 13: SettingsStore location persistence round-trip

// Feature: photostamp-test-suite, Property 13: SettingsStore location persistence round-trip
// Validates: Requirements 10.1, 10.3

/// Generates a `Double` uniformly in the closed range `[lo, hi]`.
private func genDouble(lo: Double, hi: Double) -> Gen<Double> {
    // SwiftCheck's `Gen.choose` works on `Double` via the `RandomType` conformance.
    // We map a uniform integer in [0, 1_000_000] to the target range for precision.
    return Gen<Int>.choose((0, 1_000_000)).map { i in
        lo + (hi - lo) * (Double(i) / 1_000_000.0)
    }
}

/// Generates a latitude value in `[-90.0, 90.0]`.
private let arbitraryLatitude: Gen<Double> = genDouble(lo: -90.0, hi: 90.0)

/// Generates a longitude value in `[-180.0, 180.0]`.
private let arbitraryLongitude: Gen<Double> = genDouble(lo: -180.0, hi: 180.0)

@Suite("SettingsStore — Property Tests", .serialized)
struct SettingsStorePropertyTests {

    // MARK: - Property 13

    /// Property 13: SettingsStore location persistence round-trip.
    ///
    /// For any valid latitude in `[-90, 90]` and longitude in `[-180, 180]`, setting
    /// `savedLocationLat`, `savedLocationLon`, and `hasLocation = true` on a `SettingsStore`
    /// instance and then reading those values from a **new** `SettingsStore` instance backed
    /// by the **same** `UserDefaults` suite SHALL return the same values.
    ///
    /// **Validates: Requirements 10.1, 10.3**
    @Test("Property 13: SettingsStore location persistence round-trip")
    func property13_locationPersistenceRoundTrip() {
        // Feature: photostamp-test-suite, Property 13: SettingsStore location persistence round-trip
        property("SettingsStore location persistence round-trip") <- forAll(arbitraryLatitude, arbitraryLongitude) { lat, lon in
            let suiteName = UUID().uuidString
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                return TestResult.failed("Could not create UserDefaults suite \(suiteName)")
            }
            defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

            // Write via the first instance
            let store1 = SettingsStore(defaults: defaults)
            store1.hasLocation = true
            store1.savedLocationLat = lat
            store1.savedLocationLon = lon

            // Flush to disk before reading back
            defaults.synchronize()

            // Read back via a second instance on the same suite
            let store2 = SettingsStore(defaults: defaults)

            guard store2.hasLocation == true else {
                return TestResult.failed("hasLocation was not persisted (lat=\(lat), lon=\(lon))")
            }
            guard store2.savedLocationLat == lat else {
                return TestResult.failed(
                    "savedLocationLat mismatch: wrote \(lat), read \(store2.savedLocationLat)"
                )
            }
            guard store2.savedLocationLon == lon else {
                return TestResult.failed(
                    "savedLocationLon mismatch: wrote \(lon), read \(store2.savedLocationLon)"
                )
            }

            return TestResult.succeeded
        }
    }

    // MARK: - Property 14

    /// Property 14: SettingsStore applyTime preserves hour and minute.
    ///
    /// For any hour in `[0, 23]` and minute in `[0, 59]`, calling
    /// `SettingsStore.applyTime(to:)` with `timeMode == .default_` and those values
    /// configured SHALL return a `Date` whose hour and minute components (in the
    /// configured timezone) equal the configured values.
    ///
    /// `applyTime` accepts a 12-hour clock value (`defaultTimeHour` in `[1, 12]`) paired
    /// with `defaultTimeIsAM`.  We convert the generated 24-hour value to 12-hour + AM/PM
    /// before setting it on the store, then verify the output matches the original 24-hour
    /// expectation.
    ///
    /// **Validates: Requirements 10.5**
    @Test("Property 14: SettingsStore applyTime preserves hour and minute")
    func property14_applyTimePreservesHourAndMinute() {
        // Feature: photostamp-test-suite, Property 14: SettingsStore applyTime preserves hour and minute
        let genHour   = Gen<Int>.choose((0, 23))
        let genMinute = Gen<Int>.choose((0, 59))

        property("SettingsStore applyTime preserves hour and minute") <- forAll(genHour, genMinute) { hour24, minute in
            let suiteName = UUID().uuidString
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                return TestResult.failed("Could not create UserDefaults suite \(suiteName)")
            }
            defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

            // Convert 24-hour value to the 12-hour representation used by SettingsStore:
            //   hour24 == 0  → 12 AM  (hour12 = 12, isAM = true)
            //   hour24 1–11  → 1–11 AM (hour12 = hour24, isAM = true)
            //   hour24 == 12 → 12 PM  (hour12 = 12, isAM = false)
            //   hour24 13–23 → 1–11 PM (hour12 = hour24 - 12, isAM = false)
            let isAM: Bool = hour24 < 12
            let hour12: Int = {
                let h = hour24 % 12
                return h == 0 ? 12 : h
            }()

            // Use UTC so the calendar arithmetic is unambiguous.
            let store = SettingsStore(defaults: defaults)
            store.timeMode = .default_
            store.defaultTimeHour   = hour12
            store.defaultTimeMinute = minute
            store.defaultTimeIsAM   = isAM
            store.defaultTimezone   = "UTC"

            // Use a fixed base date; the calendar day should be irrelevant to the property.
            var baseComps = DateComponents()
            baseComps.year = 2000; baseComps.month = 1; baseComps.day = 1
            baseComps.hour = 0; baseComps.minute = 0; baseComps.second = 0
            baseComps.timeZone = TimeZone(identifier: "UTC")
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            guard let baseDate = cal.date(from: baseComps) else {
                return TestResult.failed("Could not construct base date")
            }

            let result = store.applyTime(to: baseDate)
            let comps  = cal.dateComponents([.hour, .minute], from: result)

            guard let resultHour = comps.hour, let resultMinute = comps.minute else {
                return TestResult.failed(
                    "Could not extract hour/minute from result (hour24=\(hour24), minute=\(minute))"
                )
            }

            guard resultHour == hour24 else {
                return TestResult.failed(
                    "Hour mismatch: expected \(hour24), got \(resultHour) " +
                    "(hour12=\(hour12), isAM=\(isAM), minute=\(minute))"
                )
            }
            guard resultMinute == minute else {
                return TestResult.failed(
                    "Minute mismatch: expected \(minute), got \(resultMinute) " +
                    "(hour24=\(hour24), hour12=\(hour12), isAM=\(isAM))"
                )
            }

            return TestResult.succeeded
        }
    }
}
