import Testing
import SwiftCheck
import CoreLocation
@testable import DataStamp
import Foundation

// MARK: - Generators

/// Generates a Double in [lo, hi] by mapping an integer in [0, 1_000_000].
private func genDouble(lo: Double, hi: Double) -> Gen<Double> {
    Gen<Int>.choose((0, 1_000_000)).map { i in
        lo + Double(i) / 1_000_000.0 * (hi - lo)
    }
}

/// Generates a latitude magnitude in [0, 90].
private let genLatMag: Gen<Double> = genDouble(lo: 0.0, hi: 90.0)

/// Generates a longitude magnitude in [0, 180].
private let genLonMag: Gen<Double> = genDouble(lo: 0.0, hi: 180.0)

/// Generates a latitude ref: "N" or "S".
private let genLatRef: Gen<String> = Gen<String>.fromElements(of: ["N", "S"])

/// Generates a longitude ref: "E" or "W".
private let genLonRef: Gen<String> = Gen<String>.fromElements(of: ["E", "W"])

/// Generates a full latitude in [−90, +90].
private let genLat: Gen<Double> = genDouble(lo: -90.0, hi: 90.0)

/// Generates a full longitude in [−180, +180].
private let genLon: Gen<Double> = genDouble(lo: -180.0, hi: 180.0)

// MARK: - DMS / Decimal string helpers

/// Format a magnitude as a DMS string: `"39 deg 44' 21.16\""`.
private func toDMS(_ magnitude: Double) -> String {
    let totalSeconds = magnitude * 3600.0
    let degrees = Int(totalSeconds / 3600.0)
    let minutes = Int((totalSeconds - Double(degrees) * 3600.0) / 60.0)
    let seconds = totalSeconds - Double(degrees) * 3600.0 - Double(minutes) * 60.0
    return String(format: "%d deg %d' %.6f\"", degrees, minutes, seconds)
}

/// Format a magnitude as a decimal string: `"39.739211"`.
private func toDecimal(_ magnitude: Double) -> String {
    return String(format: "%.6f", magnitude)
}

/// Build a synthetic `MetadataEngine.ExifData` from the four GPS field values.
private func makeExifData(
    latStr: String, latRef: String,
    lonStr: String, lonRef: String
) -> MetadataEngine.ExifData {
    MetadataEngine.ExifData(fields: [
        (key: "GPSLatitude",     value: latStr),
        (key: "GPSLatitudeRef",  value: latRef),
        (key: "GPSLongitude",    value: lonStr),
        (key: "GPSLongitudeRef", value: lonRef),
    ])
}

// MARK: - Invalid value pools

private let invalidLatRefs: [String] = ["X", "x", "n", "s", "", "NS", "NE", "SW", "1", " ", "North"]
private let invalidLonRefs: [String] = ["X", "x", "e", "w", "", "EW", "NE", "SW", "1", " ", "East"]

private let invalidNumericValues: [String] = [
    "abc", "NaN", "inf", "-inf", "", "  ", "1.2.3", "deg", "°",
    "91.0",    // lat out of range
    "-91.0",   // lat out of range
    "181.0",   // lon out of range
    "-181.0",  // lon out of range
    "999",
    "1e308",
]

// MARK: - Property-Based Test Suite

@Suite("ExifGPSParser — Property-Based Tests", .serialized)
struct ExifGPSParserPropertyTests {

    // MARK: - Property 1

    // Feature: photo-location-map-preview, Property 1: Parsed coordinate is in valid range and has correct sign
    // Validates: Requirements 1.1, 1.2, 1.3

    @Test("Property 1: Parsed coordinate is in valid range and has correct sign")
    func property1_parsedCoordinateInValidRangeWithCorrectSign() {
        property("Parsed coordinate is in valid range and has correct sign") <- forAll(
            genLatMag, genLatRef, genLonMag, genLonRef,
            pf: { latMag, latRef, lonMag, lonRef in

                // Test decimal format
                let decimalExif = makeExifData(
                    latStr: toDecimal(latMag), latRef: latRef,
                    lonStr: toDecimal(lonMag), lonRef: lonRef
                )
                guard let decimalCoord = ExifGPSParser.coordinate(from: decimalExif) else {
                    return false
                }

                // Test DMS format
                let dmsExif = makeExifData(
                    latStr: toDMS(latMag), latRef: latRef,
                    lonStr: toDMS(lonMag), lonRef: lonRef
                )
                guard let dmsCoord = ExifGPSParser.coordinate(from: dmsExif) else {
                    return false
                }

                // Both results must be in valid range
                guard decimalCoord.latitude  >= -90.0,  decimalCoord.latitude  <= 90.0  else { return false }
                guard decimalCoord.longitude >= -180.0, decimalCoord.longitude <= 180.0 else { return false }
                guard dmsCoord.latitude  >= -90.0,  dmsCoord.latitude  <= 90.0  else { return false }
                guard dmsCoord.longitude >= -180.0, dmsCoord.longitude <= 180.0 else { return false }

                // Sign must match ref (for non-zero magnitudes)
                if latMag > 0.0 {
                    let expectedLatSign: Double = latRef == "S" ? -1.0 : 1.0
                    guard (decimalCoord.latitude  * expectedLatSign) >= 0.0 else { return false }
                    guard (dmsCoord.latitude      * expectedLatSign) >= 0.0 else { return false }
                }
                if lonMag > 0.0 {
                    let expectedLonSign: Double = lonRef == "W" ? -1.0 : 1.0
                    guard (decimalCoord.longitude * expectedLonSign) >= 0.0 else { return false }
                    guard (dmsCoord.longitude     * expectedLonSign) >= 0.0 else { return false }
                }

                return true
            }
        )
    }

    // MARK: - Property 2

    // Feature: photo-location-map-preview, Property 2: Invalid or missing GPS fields produce nil
    // Validates: Requirements 1.4, 1.5, 1.6

    @Test("Property 2: Invalid or missing GPS fields produce nil")
    func property2_invalidOrMissingGPSFieldsProduceNil() {
        // Case A: Missing one or more fields (mask 1..15 means at least one field is absent)
        let genMissingMask = Gen<Int>.choose((1, 15))

        property("Missing GPS fields produce nil") <- forAll(
            genLatMag, genLatRef, genLonMag, genLonRef, genMissingMask,
            pf: { latMag, latRef, lonMag, lonRef, mask in
                var fields: [(key: String, value: String)] = []
                if mask & 1 == 0 { fields.append((key: "GPSLatitude",     value: toDecimal(latMag))) }
                if mask & 2 == 0 { fields.append((key: "GPSLatitudeRef",  value: latRef)) }
                if mask & 4 == 0 { fields.append((key: "GPSLongitude",    value: toDecimal(lonMag))) }
                if mask & 8 == 0 { fields.append((key: "GPSLongitudeRef", value: lonRef)) }
                let exif = MetadataEngine.ExifData(fields: fields)
                return ExifGPSParser.coordinate(from: exif) == nil
            }
        )

        // Case B: Invalid LatRef
        let genInvalidLatRef = Gen<String>.fromElements(of: invalidLatRefs)
        property("Invalid LatRef produces nil") <- forAll(
            genLatMag, genInvalidLatRef, genLonMag, genLonRef,
            pf: { latMag, badLatRef, lonMag, lonRef in
                let exif = makeExifData(
                    latStr: toDecimal(latMag), latRef: badLatRef,
                    lonStr: toDecimal(lonMag), lonRef: lonRef
                )
                return ExifGPSParser.coordinate(from: exif) == nil
            }
        )

        // Case C: Invalid LonRef
        let genInvalidLonRef = Gen<String>.fromElements(of: invalidLonRefs)
        property("Invalid LonRef produces nil") <- forAll(
            genLatMag, genLatRef, genLonMag, genInvalidLonRef,
            pf: { latMag, latRef, lonMag, badLonRef in
                let exif = makeExifData(
                    latStr: toDecimal(latMag), latRef: latRef,
                    lonStr: toDecimal(lonMag), lonRef: badLonRef
                )
                return ExifGPSParser.coordinate(from: exif) == nil
            }
        )

        // Case D: Non-numeric or out-of-range latitude value
        let genInvalidNumeric = Gen<String>.fromElements(of: invalidNumericValues)
        property("Non-numeric or out-of-range lat value produces nil") <- forAll(
            genInvalidNumeric, genLatRef, genLonMag, genLonRef,
            pf: { badLat, latRef, lonMag, lonRef in
                let exif = makeExifData(
                    latStr: badLat, latRef: latRef,
                    lonStr: toDecimal(lonMag), lonRef: lonRef
                )
                return ExifGPSParser.coordinate(from: exif) == nil
            }
        )

        // Case E: Non-numeric or out-of-range longitude value
        property("Non-numeric or out-of-range lon value produces nil") <- forAll(
            genLatMag, genLatRef, genInvalidNumeric, genLonRef,
            pf: { latMag, latRef, badLon, lonRef in
                let exif = makeExifData(
                    latStr: toDecimal(latMag), latRef: latRef,
                    lonStr: badLon, lonRef: lonRef
                )
                return ExifGPSParser.coordinate(from: exif) == nil
            }
        )
    }

    // MARK: - Property 3

    // Feature: photo-location-map-preview, Property 3: Formatted coordinate string matches expected pattern
    // Validates: Requirements 6.1, 6.2, 6.3

    @Test("Property 3: Formatted coordinate string matches expected pattern")
    func property3_formattedCoordinateMatchesPattern() {
        // Regex: digits.4digits° [NS], digits.4digits° [EW]
        let pattern = #"^\d+\.\d{4}° [NS], \d+\.\d{4}° [EW]$"#
        let regex = try! NSRegularExpression(pattern: pattern)

        property("Formatted coordinate string matches expected pattern") <- forAll(
            genLat, genLon,
            pf: { lat, lon in
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let formatted = ExifGPSParser.formatCoordinate(coord)

                // Must match the regex
                let range = NSRange(formatted.startIndex..., in: formatted)
                guard regex.firstMatch(in: formatted, range: range) != nil else {
                    return false
                }

                // Hemisphere indicators must be correct
                let expectedLatHem = lat >= 0 ? "N" : "S"
                let expectedLonHem = lon >= 0 ? "E" : "W"

                guard formatted.contains("° \(expectedLatHem),") else { return false }
                guard formatted.hasSuffix("° \(expectedLonHem)") else { return false }

                return true
            }
        )
    }

    // MARK: - Property 4

    // Feature: photo-location-map-preview, Property 4: Format → parse round-trip preserves coordinate within precision
    // Validates: Requirement 6.4

    @Test("Property 4: Format → parse round-trip preserves coordinate within precision")
    func property4_formatParseRoundTripPreservesCoordinate() {
        property("Format → parse round-trip preserves coordinate within 0.00005°") <- forAll(
            genLat, genLon,
            pf: { lat, lon in
                let original = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let formatted = ExifGPSParser.formatCoordinate(original)

                // The formatted string looks like: "39.7392° N, 104.9903° W"
                // Split on ", " to get lat part and lon part.
                let parts = formatted.components(separatedBy: ", ")
                guard parts.count == 2 else { return false }

                // Extract numeric value and hemisphere from each part
                guard let latComponents = splitCoordPart(parts[0]),
                      let lonComponents = splitCoordPart(parts[1]) else { return false }

                let syntheticExif = makeExifData(
                    latStr: latComponents.value, latRef: latComponents.hem,
                    lonStr: lonComponents.value, lonRef: lonComponents.hem
                )

                guard let result = ExifGPSParser.coordinate(from: syntheticExif) else {
                    return false
                }

                let latDiff = abs(original.latitude  - result.latitude)
                let lonDiff = abs(original.longitude - result.longitude)

                return latDiff <= 0.00005 && lonDiff <= 0.00005
            }
        )
    }

    // MARK: - Property 5

    // Feature: photo-location-map-preview, Property 5: DMS and decimal parsing agree within tolerance
    // Validates: Requirement 1.7

    @Test("Property 5: DMS and decimal parsing agree within tolerance")
    func property5_dmsAndDecimalParsingAgreeWithinTolerance() {
        property("DMS and decimal parsing agree within 0.0001°") <- forAll(
            genLatMag, genLonMag,
            pf: { latMag, lonMag in
                // Use "N" and "E" for both (sign is irrelevant for the tolerance comparison)
                let dmsExif = makeExifData(
                    latStr: toDMS(latMag),     latRef: "N",
                    lonStr: toDMS(lonMag),     lonRef: "E"
                )
                let decimalExif = makeExifData(
                    latStr: toDecimal(latMag), latRef: "N",
                    lonStr: toDecimal(lonMag), lonRef: "E"
                )

                guard let dmsCoord     = ExifGPSParser.coordinate(from: dmsExif),
                      let decimalCoord = ExifGPSParser.coordinate(from: decimalExif) else {
                    return false
                }

                let latDiff = abs(dmsCoord.latitude  - decimalCoord.latitude)
                let lonDiff = abs(dmsCoord.longitude - decimalCoord.longitude)

                return latDiff <= 0.0001 && lonDiff <= 0.0001
            }
        )
    }
}

// MARK: - Private helpers for Property 4

/// Splits a formatted coordinate part like `"39.7392° N"` into `(value: "39.7392", hem: "N")`.
private func splitCoordPart(_ part: String) -> (value: String, hem: String)? {
    let trimmed = part.trimmingCharacters(in: .whitespaces)
    let separator = "° "
    guard let sepRange = trimmed.range(of: separator) else { return nil }
    let value = String(trimmed[trimmed.startIndex..<sepRange.lowerBound])
    let hem   = String(trimmed[sepRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    guard !value.isEmpty, !hem.isEmpty else { return nil }
    return (value: value, hem: hem)
}

// MARK: - Unit / Example-Based Test Suite

@Suite("ExifGPSParser — Unit Tests")
struct ExifGPSParserUnitTests {

    // MARK: - Helpers

    /// Build a full ExifData with all four GPS fields present.
    private func fullExifData(
        latStr: String = "39.739211",
        latRef: String = "N",
        lonStr: String = "104.990300",
        lonRef: String = "W"
    ) -> MetadataEngine.ExifData {
        MetadataEngine.ExifData(fields: [
            (key: "GPSLatitude",     value: latStr),
            (key: "GPSLatitudeRef",  value: latRef),
            (key: "GPSLongitude",    value: lonStr),
            (key: "GPSLongitudeRef", value: lonRef),
        ])
    }

    // MARK: - Missing field tests (Requirements 1.5)

    @Test("coordinate(from:) returns nil when GPSLatitude is missing")
    func missingGPSLatitude() {
        let exif = MetadataEngine.ExifData(fields: [
            (key: "GPSLatitudeRef",  value: "N"),
            (key: "GPSLongitude",    value: "104.990300"),
            (key: "GPSLongitudeRef", value: "W"),
        ])
        #expect(ExifGPSParser.coordinate(from: exif) == nil)
    }

    @Test("coordinate(from:) returns nil when GPSLatitudeRef is missing")
    func missingGPSLatitudeRef() {
        let exif = MetadataEngine.ExifData(fields: [
            (key: "GPSLatitude",     value: "39.739211"),
            (key: "GPSLongitude",    value: "104.990300"),
            (key: "GPSLongitudeRef", value: "W"),
        ])
        #expect(ExifGPSParser.coordinate(from: exif) == nil)
    }

    @Test("coordinate(from:) returns nil when GPSLongitude is missing")
    func missingGPSLongitude() {
        let exif = MetadataEngine.ExifData(fields: [
            (key: "GPSLatitude",     value: "39.739211"),
            (key: "GPSLatitudeRef",  value: "N"),
            (key: "GPSLongitudeRef", value: "W"),
        ])
        #expect(ExifGPSParser.coordinate(from: exif) == nil)
    }

    @Test("coordinate(from:) returns nil when GPSLongitudeRef is missing")
    func missingGPSLongitudeRef() {
        let exif = MetadataEngine.ExifData(fields: [
            (key: "GPSLatitude",     value: "39.739211"),
            (key: "GPSLatitudeRef",  value: "N"),
            (key: "GPSLongitude",    value: "104.990300"),
        ])
        #expect(ExifGPSParser.coordinate(from: exif) == nil)
    }

    // MARK: - Invalid ref value tests (Requirements 1.4)

    @Test("coordinate(from:) returns nil for invalid LatRef 'X'")
    func invalidLatRefX() {
        let exif = fullExifData(latRef: "X")
        #expect(ExifGPSParser.coordinate(from: exif) == nil)
    }

    @Test("coordinate(from:) returns nil for invalid LatRef ''")
    func invalidLatRefEmpty() {
        let exif = fullExifData(latRef: "")
        #expect(ExifGPSParser.coordinate(from: exif) == nil)
    }

    @Test("coordinate(from:) returns nil for invalid LatRef 'n' (lowercase)")
    func invalidLatRefLowercase() {
        let exif = fullExifData(latRef: "n")
        #expect(ExifGPSParser.coordinate(from: exif) == nil)
    }

    // MARK: - DMS parsing test (Requirements 1.7)

    @Test("coordinate(from:) correctly parses DMS string '39 deg 44' 21.16\"' to ~39.7392°")
    func parseDMSString() throws {
        let exif = fullExifData(latStr: #"39 deg 44' 21.16""#, latRef: "N",
                                lonStr: "104.990300", lonRef: "W")
        let coord = try #require(ExifGPSParser.coordinate(from: exif))
        #expect(abs(coord.latitude - 39.7392) < 0.0001,
                "Expected latitude ≈ 39.7392°, got \(coord.latitude)")
    }

    // MARK: - Decimal parsing test (Requirements 1.7)

    @Test("coordinate(from:) correctly parses decimal string '39.739211' to ~39.7392°")
    func parseDecimalString() throws {
        let exif = fullExifData(latStr: "39.739211", latRef: "N",
                                lonStr: "104.990300", lonRef: "W")
        let coord = try #require(ExifGPSParser.coordinate(from: exif))
        #expect(abs(coord.latitude - 39.7392) < 0.0001,
                "Expected latitude ≈ 39.7392°, got \(coord.latitude)")
    }

    // MARK: - formatCoordinate tests (Requirements 6.1, 6.2, 6.3)

    @Test("formatCoordinate(_:) produces exact string for known coordinate")
    func formatKnownCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let result = ExifGPSParser.formatCoordinate(coord)
        #expect(result == "39.7392° N, 104.9903° W",
                "Expected '39.7392° N, 104.9903° W', got '\(result)'")
    }

    @Test("formatCoordinate(_:) uses 'N' for zero latitude and 'E' for zero longitude")
    func formatZeroCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let result = ExifGPSParser.formatCoordinate(coord)
        #expect(result.contains("° N,"), "Expected 'N' hemisphere for zero latitude, got '\(result)'")
        #expect(result.hasSuffix("° E"), "Expected 'E' hemisphere for zero longitude, got '\(result)'")
    }
}
