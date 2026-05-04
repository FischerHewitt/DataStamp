import Testing
@testable import DataStamp
import Foundation

// Feature: photostamp-test-suite
// Validates: Requirements 19.1, 19.2, 19.3

@Suite("ExifPreviewSheet Filter Logic")
struct ExifPreviewSheetFilterTests {

    // MARK: - Helpers

    /// A small set of sample EXIF fields used across multiple tests.
    private let sampleFields: [(key: String, value: String)] = [
        (key: "DateTimeOriginal", value: "1977:07:07 12:00:00"),
        (key: "Make",             value: "Apple"),
        (key: "Model",            value: "iPhone 15 Pro"),
        (key: "GPSLatitude",      value: "37.3318"),
        (key: "GPSLongitude",     value: "-122.0312"),
        (key: "ExposureTime",     value: "1/120"),
        (key: "FNumber",          value: "1.8"),
    ]

    // MARK: - Requirement 19.1: Empty search term returns all fields

    @Test("filterExifFields returns all fields when searchText is empty")
    func emptySearchReturnsAllFields() {
        let result = filterExifFields(sampleFields, searchText: "")
        #expect(result.count == sampleFields.count,
                "Expected all \(sampleFields.count) fields to be returned for an empty search term")
    }

    @Test("filterExifFields returns all fields when searchText is empty and field list is empty")
    func emptySearchOnEmptyFieldsReturnsEmpty() {
        let result = filterExifFields([], searchText: "")
        #expect(result.isEmpty,
                "Expected empty result when both fields and searchText are empty")
    }

    @Test("filterExifFields returns all fields when searchText is empty and field list has one entry")
    func emptySearchOnSingleFieldReturnsIt() {
        let fields = [(key: "Make", value: "Canon")]
        let result = filterExifFields(fields, searchText: "")
        #expect(result.count == 1)
        #expect(result[0].key == "Make")
        #expect(result[0].value == "Canon")
    }

    // MARK: - Requirement 19.2: Matching term returns subset

    @Test("filterExifFields returns only fields whose key contains the search term")
    func matchingKeyReturnsSubset() {
        // "GPS" matches GPSLatitude and GPSLongitude keys
        let result = filterExifFields(sampleFields, searchText: "GPS")
        #expect(result.count == 2,
                "Expected 2 fields matching key 'GPS', got \(result.count)")
        #expect(result.allSatisfy { $0.key.contains("GPS") || $0.value.contains("GPS") },
                "Every returned field should contain 'GPS' in key or value")
    }

    @Test("filterExifFields returns only fields whose value contains the search term")
    func matchingValueReturnsSubset() {
        // "Apple" matches the Make field's value
        let result = filterExifFields(sampleFields, searchText: "Apple")
        #expect(result.count == 1,
                "Expected 1 field matching value 'Apple', got \(result.count)")
        #expect(result[0].key == "Make")
        #expect(result[0].value == "Apple")
    }

    @Test("filterExifFields returns fields matching either key or value")
    func matchingKeyOrValueReturnsSubset() {
        // "1977" appears in the DateTimeOriginal value
        let result = filterExifFields(sampleFields, searchText: "1977")
        #expect(result.count == 1)
        #expect(result[0].key == "DateTimeOriginal")
    }

    @Test("filterExifFields returns empty array when no fields match the search term")
    func nonMatchingTermReturnsEmpty() {
        let result = filterExifFields(sampleFields, searchText: "Nikon")
        #expect(result.isEmpty,
                "Expected no fields to match 'Nikon'")
    }

    @Test("filterExifFields returns empty array for a non-matching term on an empty field list")
    func nonMatchingTermOnEmptyFieldsReturnsEmpty() {
        let result = filterExifFields([], searchText: "anything")
        #expect(result.isEmpty)
    }

    // MARK: - Requirement 19.2: Case-insensitive matching

    @Test("filterExifFields matches key case-insensitively (lowercase search)")
    func caseInsensitiveKeyMatchLowercase() {
        // "datetimeoriginal" should match "DateTimeOriginal"
        let result = filterExifFields(sampleFields, searchText: "datetimeoriginal")
        #expect(result.count == 1,
                "Expected case-insensitive key match for 'datetimeoriginal'")
        #expect(result[0].key == "DateTimeOriginal")
    }

    @Test("filterExifFields matches key case-insensitively (uppercase search)")
    func caseInsensitiveKeyMatchUppercase() {
        // "MAKE" should match "Make"
        let result = filterExifFields(sampleFields, searchText: "MAKE")
        #expect(result.count == 1,
                "Expected case-insensitive key match for 'MAKE'")
        #expect(result[0].key == "Make")
    }

    @Test("filterExifFields matches value case-insensitively (lowercase search)")
    func caseInsensitiveValueMatchLowercase() {
        // "apple" should match value "Apple"
        let result = filterExifFields(sampleFields, searchText: "apple")
        #expect(result.count == 1,
                "Expected case-insensitive value match for 'apple'")
        #expect(result[0].value == "Apple")
    }

    @Test("filterExifFields matches value case-insensitively (mixed-case search)")
    func caseInsensitiveValueMatchMixedCase() {
        // "iPHONE" should match value "iPhone 15 Pro"
        let result = filterExifFields(sampleFields, searchText: "iPHONE")
        #expect(result.count == 1,
                "Expected case-insensitive value match for 'iPHONE'")
        #expect(result[0].key == "Model")
    }

    @Test("filterExifFields matches key case-insensitively (mixed-case search)")
    func caseInsensitiveKeyMatchMixedCase() {
        // "gPsLaTiTuDe" should match key "GPSLatitude"
        let result = filterExifFields(sampleFields, searchText: "gPsLaTiTuDe")
        #expect(result.count == 1,
                "Expected case-insensitive key match for 'gPsLaTiTuDe'")
        #expect(result[0].key == "GPSLatitude")
    }

    // MARK: - Requirement 19.3: Clearing search term restores full field list

    @Test("filterExifFields restores all fields when search term is cleared (set to empty string)")
    func clearingSearchRestoresAllFields() {
        // Simulate a user typing a search term and then clearing it
        let searchTerm = "GPS"

        // After typing: only GPS fields
        let filtered = filterExifFields(sampleFields, searchText: searchTerm)
        #expect(filtered.count < sampleFields.count,
                "Filtered result should be a strict subset when searchText is non-empty")

        // After clearing: all fields restored
        let restored = filterExifFields(sampleFields, searchText: "")
        #expect(restored.count == sampleFields.count,
                "Expected all \(sampleFields.count) fields to be restored after clearing the search term")
    }

    @Test("filterExifFields restores all fields after a non-matching search is cleared")
    func clearingNonMatchingSearchRestoresAllFields() {
        // After a non-matching search: empty result
        let noMatch = filterExifFields(sampleFields, searchText: "Nikon")
        #expect(noMatch.isEmpty)

        // After clearing: all fields restored
        let restored = filterExifFields(sampleFields, searchText: "")
        #expect(restored.count == sampleFields.count,
                "Expected all fields to be restored after clearing a non-matching search term")
    }

    @Test("filterExifFields result count is always ≤ total field count for any search term")
    func resultCountNeverExceedsTotalCount() {
        let searchTerms = ["", "GPS", "Apple", "Nikon", "1977", "a", "EXIF", "xyz123"]
        for term in searchTerms {
            let result = filterExifFields(sampleFields, searchText: term)
            #expect(result.count <= sampleFields.count,
                    "Result count (\(result.count)) exceeded total field count (\(sampleFields.count)) for search term '\(term)'")
        }
    }
}
