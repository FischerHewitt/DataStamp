import Testing
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 6.1, 6.2

@Suite("MetadataEngine Date Formatting")
struct MetadataEngineDateFormatTests {

    // MARK: - formatDate

    @Test("formatDate returns yyyy:MM:dd HH:mm:ss pattern for a known date")
    func formatDatePatternKnownDate() {
        // July 7, 1977 at 12:34:56 UTC
        var components = DateComponents()
        components.year = 1977
        components.month = 7
        components.day = 7
        components.hour = 12
        components.minute = 34
        components.second = 56
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = MetadataEngine.formatDate(date)

        // Verify the pattern yyyy:MM:dd HH:mm:ss using a regex
        let pattern = /^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}$/
        #expect(result.wholeMatch(of: pattern) != nil,
                "Expected '\(result)' to match pattern yyyy:MM:dd HH:mm:ss")
    }

    @Test("formatDate returns yyyy:MM:dd HH:mm:ss pattern for current date")
    func formatDatePatternCurrentDate() {
        let result = MetadataEngine.formatDate(Date())

        let pattern = /^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}$/
        #expect(result.wholeMatch(of: pattern) != nil,
                "Expected '\(result)' to match pattern yyyy:MM:dd HH:mm:ss")
    }

    @Test("formatDate uses colon as date separator, not dash or slash")
    func formatDateUsesColonSeparator() {
        // Use local timezone so the formatter output matches the constructed components
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        components.hour = 9
        components.minute = 5
        components.second = 3
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let result = MetadataEngine.formatDate(date)

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

        let result = MetadataEngine.formatDate(date)

        // Build expected using the same formatter (local timezone) as MetadataEngine
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let expected = formatter.string(from: date)

        #expect(result == expected,
                "Expected '\(expected)', got '\(result)'")
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

        let result = MetadataEngine.formatDateForFilename(date)

        let pattern = /^\d{4}-\d{2}-\d{2}$/
        #expect(result.wholeMatch(of: pattern) != nil,
                "Expected '\(result)' to match pattern yyyy-MM-dd")
    }

    @Test("formatDateForFilename returns yyyy-MM-dd pattern for current date")
    func formatDateForFilenamePatternCurrentDate() {
        let result = MetadataEngine.formatDateForFilename(Date())

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

        let result = MetadataEngine.formatDateForFilename(date)

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

        let result = MetadataEngine.formatDateForFilename(date)

        // Build expected using the same formatter (local timezone) as MetadataEngine
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let expected = formatter.string(from: date)

        #expect(result == expected,
                "Expected '\(expected)', got '\(result)'")
    }

    @Test("formatDateForFilename result has exactly 10 characters")
    func formatDateForFilenameLength() {
        let result = MetadataEngine.formatDateForFilename(Date())
        #expect(result.count == 10,
                "Expected 10 characters (yyyy-MM-dd), got \(result.count) in '\(result)'")
    }
}
