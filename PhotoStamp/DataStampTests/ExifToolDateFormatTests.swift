import Testing
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 11.1, 11.2

@Suite("ExifTool Date Formatting")
struct ExifToolDateFormatTests {

    // MARK: - formatDate

    @Test("formatDate returns yyyy:MM:dd HH:mm:ss pattern for a known date")
    func formatDatePatternKnownDate() {
        // July 7, 1977 at 12:30:45 UTC
        var components = DateComponents()
        components.year = 1977
        components.month = 7
        components.day = 7
        components.hour = 12
        components.minute = 30
        components.second = 45
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = ExifTool.formatDate(date)

        // Verify the pattern yyyy:MM:dd HH:mm:ss using a regex
        let pattern = /^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}$/
        #expect(result.wholeMatch(of: pattern) != nil,
                "Expected '\(result)' to match pattern yyyy:MM:dd HH:mm:ss")
    }

    @Test("formatDate returns yyyy:MM:dd HH:mm:ss pattern for current date")
    func formatDatePatternCurrentDate() {
        let result = ExifTool.formatDate(Date())

        let pattern = /^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}$/
        #expect(result.wholeMatch(of: pattern) != nil,
                "Expected '\(result)' to match pattern yyyy:MM:dd HH:mm:ss")
    }

    @Test("formatDate uses colon as date separator, not dash or slash")
    func formatDateUsesColonSeparator() {
        // Use local timezone (no explicit timezone) so the formatter output matches
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        components.hour = 9
        components.minute = 5
        components.second = 3
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = ExifTool.formatDate(date)

        // The date portion must use colons: "2024:03:15"
        #expect(result.hasPrefix("2024:03:15"),
                "Expected date portion to be '2024:03:15', got '\(result)'")
        // The time portion must be " 09:05:03"
        #expect(result.hasSuffix(" 09:05:03"),
                "Expected time portion to be ' 09:05:03', got '\(result)'")
    }

    @Test("formatDate zero-pads month, day, hour, minute, second")
    func formatDateZeroPads() {
        // Use local timezone (no explicit timezone) so the formatter output matches
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 2
        components.hour = 3
        components.minute = 4
        components.second = 5
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = ExifTool.formatDate(date)

        // Verify using a DateFormatter with the same format (local timezone) as ExifTool
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let expected = formatter.string(from: date)

        #expect(result == expected,
                "Expected '\(expected)', got '\(result)'")
    }

    @Test("formatDate output can be parsed back by a yyyy:MM:dd HH:mm:ss formatter")
    func formatDateRoundTrip() {
        var components = DateComponents()
        components.year = 2023
        components.month = 11
        components.day = 28
        components.hour = 8
        components.minute = 0
        components.second = 0
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let formatted = ExifTool.formatDate(date)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let parsed = formatter.date(from: formatted)

        #expect(parsed != nil,
                "Expected '\(formatted)' to be parseable with format yyyy:MM:dd HH:mm:ss")
        if let parsed {
            #expect(Calendar.current.isDate(parsed, inSameDayAs: date),
                    "Expected parsed date to be on the same calendar day as the original")
        }
    }

    @Test("formatDate produces correct values for multiple distinct dates")
    func formatDateMultipleDates() {
        // Use local timezone (no explicit timezone) so the formatter output matches
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

        let testCases: [(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int)] = [
            (1977, 7, 7, 12, 30, 45),
            (2000, 1, 1, 0, 0, 0),
            (2024, 12, 31, 23, 59, 59),
        ]

        for tc in testCases {
            var components = DateComponents()
            components.year = tc.year
            components.month = tc.month
            components.day = tc.day
            components.hour = tc.hour
            components.minute = tc.minute
            components.second = tc.second
            let date = Calendar(identifier: .gregorian).date(from: components)!

            let result = ExifTool.formatDate(date)
            let expected = formatter.string(from: date)
            #expect(result == expected,
                    "Expected '\(expected)', got '\(result)'")
        }
    }

    // MARK: - formatDateForFilename

    @Test("formatDateForFilename returns yyyy-MM-dd pattern for a known date")
    func formatDateForFilenamePatternKnownDate() {
        var components = DateComponents()
        components.year = 1977
        components.month = 7
        components.day = 7
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = ExifTool.formatDateForFilename(date)

        let pattern = /^\d{4}-\d{2}-\d{2}$/
        #expect(result.wholeMatch(of: pattern) != nil,
                "Expected '\(result)' to match pattern yyyy-MM-dd")
    }

    @Test("formatDateForFilename returns yyyy-MM-dd pattern for current date")
    func formatDateForFilenamePatternCurrentDate() {
        let result = ExifTool.formatDateForFilename(Date())

        let pattern = /^\d{4}-\d{2}-\d{2}$/
        #expect(result.wholeMatch(of: pattern) != nil,
                "Expected '\(result)' to match pattern yyyy-MM-dd")
    }

    @Test("formatDateForFilename uses dash as separator")
    func formatDateForFilenameUsesDashSeparator() {
        // Use local timezone (no explicit timezone) so the formatter output matches
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = ExifTool.formatDateForFilename(date)

        #expect(result == "2024-03-15",
                "Expected '2024-03-15', got '\(result)'")
    }

    @Test("formatDateForFilename zero-pads month and day")
    func formatDateForFilenameZeroPads() {
        // Use local timezone (no explicit timezone) so the formatter output matches
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 2
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = ExifTool.formatDateForFilename(date)

        // Build expected using the same formatter (local timezone) as ExifTool
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let expected = formatter.string(from: date)

        #expect(result == expected,
                "Expected '\(expected)', got '\(result)'")
    }

    @Test("formatDateForFilename result has exactly 10 characters")
    func formatDateForFilenameLength() {
        let result = ExifTool.formatDateForFilename(Date())
        #expect(result.count == 10,
                "Expected 10 characters (yyyy-MM-dd), got \(result.count) in '\(result)'")
    }

    @Test("formatDateForFilename produces correct values for multiple distinct dates")
    func formatDateForFilenameMultipleDates() {
        // Use local timezone (no explicit timezone) so the formatter output matches
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let testCases: [(year: Int, month: Int, day: Int)] = [
            (1977, 7, 7),
            (2000, 1, 1),
            (2024, 12, 31),
        ]

        for tc in testCases {
            var components = DateComponents()
            components.year = tc.year
            components.month = tc.month
            components.day = tc.day
            let date = Calendar(identifier: .gregorian).date(from: components)!

            let result = ExifTool.formatDateForFilename(date)
            let expected = formatter.string(from: date)
            #expect(result == expected,
                    "Expected '\(expected)', got '\(result)'")
        }
    }

    @Test("formatDateForFilename output can be parsed back by a yyyy-MM-dd formatter")
    func formatDateForFilenameRoundTrip() {
        var components = DateComponents()
        components.year = 2023
        components.month = 6
        components.day = 15
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let formatted = ExifTool.formatDateForFilename(date)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let parsed = formatter.date(from: formatted)

        #expect(parsed != nil,
                "Expected '\(formatted)' to be parseable with format yyyy-MM-dd")
        if let parsed {
            #expect(Calendar.current.isDate(parsed, inSameDayAs: date),
                    "Expected parsed date to be on the same calendar day as the original")
        }
    }
}
