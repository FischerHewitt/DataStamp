import Testing
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 8.1, 8.2, 8.3, 8.4

@Suite("FileItem Duplicate Detection")
struct FileItemDuplicateTests {

    // MARK: - Helpers

    /// Build a FileItem with the given EXIF date string (or nil).
    private func makeFileItem(exifDate: String?) -> MetadataEngine.FileItem {
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        var item = MetadataEngine.FileItem(url: url)
        item.currentExifDate = exifDate
        item.isLoadingDate = false
        return item
    }

    /// Build a Date for a specific calendar day in the local timezone.
    ///
    /// Uses the local timezone (not UTC) so that dates round-trip correctly through
    /// `DateFormatter` (which also defaults to the local timezone) and
    /// `Calendar.current.isDate(_:inSameDayAs:)` (which uses the local timezone).
    private func date(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components)!
    }

    // MARK: - Requirement 8.1: Same calendar day returns true

    @Test("isDuplicate returns true when currentExifDate is on the same calendar day as target")
    func sameDayReturnsTrue() {
        // EXIF date: July 7, 1977 at 08:00:00
        let item = makeFileItem(exifDate: "1977:07:07 08:00:00")
        // Target date: July 7, 1977 at 23:59:59 (same day, different time)
        let target = date(year: 1977, month: 7, day: 7, hour: 23, minute: 59, second: 59)

        #expect(item.isDuplicate(of: target) == true,
                "Expected isDuplicate to return true when EXIF date is on the same calendar day as target")
    }

    @Test("isDuplicate returns true when EXIF date and target are at midnight on the same day")
    func sameDayMidnightReturnsTrue() {
        let item = makeFileItem(exifDate: "2024:03:15 00:00:00")
        let target = date(year: 2024, month: 3, day: 15, hour: 0, minute: 0, second: 0)

        #expect(item.isDuplicate(of: target) == true,
                "Expected isDuplicate to return true for midnight on the same day")
    }

    @Test("isDuplicate returns true when EXIF date is end of day and target is start of day")
    func sameDayEndOfDayReturnsTrue() {
        let item = makeFileItem(exifDate: "2023:12:31 23:59:59")
        let target = date(year: 2023, month: 12, day: 31, hour: 0, minute: 0, second: 0)

        #expect(item.isDuplicate(of: target) == true,
                "Expected isDuplicate to return true when both dates are on Dec 31, 2023")
    }

    // MARK: - Requirement 8.2: Different calendar day returns false

    @Test("isDuplicate returns false when currentExifDate is on a different calendar day than target")
    func differentDayReturnsFalse() {
        // EXIF date: July 7, 1977
        let item = makeFileItem(exifDate: "1977:07:07 12:00:00")
        // Target date: July 8, 1977 (next day)
        let target = date(year: 1977, month: 7, day: 8)

        #expect(item.isDuplicate(of: target) == false,
                "Expected isDuplicate to return false when EXIF date is on a different calendar day")
    }

    @Test("isDuplicate returns false when EXIF date is one day before target")
    func oneDayBeforeReturnsFalse() {
        let item = makeFileItem(exifDate: "2024:01:14 23:59:59")
        let target = date(year: 2024, month: 1, day: 15)

        #expect(item.isDuplicate(of: target) == false,
                "Expected isDuplicate to return false when EXIF date is the day before target")
    }

    @Test("isDuplicate returns false when EXIF date is one day after target")
    func oneDayAfterReturnsFalse() {
        let item = makeFileItem(exifDate: "2024:01:16 00:00:00")
        let target = date(year: 2024, month: 1, day: 15)

        #expect(item.isDuplicate(of: target) == false,
                "Expected isDuplicate to return false when EXIF date is the day after target")
    }

    @Test("isDuplicate returns false when EXIF date is in a different year")
    func differentYearReturnsFalse() {
        let item = makeFileItem(exifDate: "2023:06:15 10:00:00")
        let target = date(year: 2024, month: 6, day: 15)

        #expect(item.isDuplicate(of: target) == false,
                "Expected isDuplicate to return false when years differ")
    }

    // MARK: - Requirement 8.3: nil currentExifDate returns false

    @Test("isDuplicate returns false when currentExifDate is nil")
    func nilExifDateReturnsFalse() {
        let item = makeFileItem(exifDate: nil)
        let target = date(year: 2024, month: 6, day: 15)

        #expect(item.isDuplicate(of: target) == false,
                "Expected isDuplicate to return false when currentExifDate is nil")
    }

    @Test("isDuplicate returns false when currentExifDate is nil regardless of target date")
    func nilExifDateReturnsFalseForAnyTarget() {
        let item = makeFileItem(exifDate: nil)

        // Test with multiple different target dates
        let targets = [
            date(year: 1970, month: 1, day: 1),
            date(year: 2000, month: 12, day: 31),
            Date()
        ]

        for target in targets {
            #expect(item.isDuplicate(of: target) == false,
                    "Expected isDuplicate to return false for nil exifDate with target \(target)")
        }
    }

    // MARK: - Requirement 8.4: yyyy:MM:dd HH:mm:ss format parses correctly

    @Test("isDuplicate correctly parses yyyy:MM:dd HH:mm:ss format")
    func exifFormatParsesCorrectly() {
        // The canonical EXIF date format
        let item = makeFileItem(exifDate: "2024:06:15 14:30:00")
        let sameDay = date(year: 2024, month: 6, day: 15)
        let differentDay = date(year: 2024, month: 6, day: 16)

        #expect(item.isDuplicate(of: sameDay) == true,
                "Expected isDuplicate to return true for same day with yyyy:MM:dd HH:mm:ss format")
        #expect(item.isDuplicate(of: differentDay) == false,
                "Expected isDuplicate to return false for different day with yyyy:MM:dd HH:mm:ss format")
    }

    @Test("isDuplicate correctly parses yyyy:MM:dd HH:mm:ss with zero-padded components")
    func exifFormatZeroPaddedParsesCorrectly() {
        // Zero-padded month, day, hour, minute, second
        let item = makeFileItem(exifDate: "2000:01:02 03:04:05")
        let sameDay = date(year: 2000, month: 1, day: 2)
        let differentDay = date(year: 2000, month: 1, day: 3)

        #expect(item.isDuplicate(of: sameDay) == true,
                "Expected isDuplicate to return true for zero-padded EXIF date on same day")
        #expect(item.isDuplicate(of: differentDay) == false,
                "Expected isDuplicate to return false for zero-padded EXIF date on different day")
    }

    @Test("isDuplicate returns false for an unparseable EXIF date string")
    func unparseableExifDateReturnsFalse() {
        let item = makeFileItem(exifDate: "not-a-date")
        let target = date(year: 2024, month: 6, day: 15)

        #expect(item.isDuplicate(of: target) == false,
                "Expected isDuplicate to return false when currentExifDate cannot be parsed")
    }

    @Test("isDuplicate returns false for an empty EXIF date string")
    func emptyExifDateReturnsFalse() {
        let item = makeFileItem(exifDate: "")
        let target = date(year: 2024, month: 6, day: 15)

        #expect(item.isDuplicate(of: target) == false,
                "Expected isDuplicate to return false for an empty currentExifDate string")
    }
}
