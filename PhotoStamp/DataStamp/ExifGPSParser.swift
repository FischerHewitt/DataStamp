import CoreLocation

// MARK: - ExifGPSParser
// Pure namespace for parsing GPS coordinates from EXIF metadata and formatting them
// for display. No stored state; no SwiftUI dependency.

enum ExifGPSParser {

    // MARK: - Coordinate parsing

    /// Parse a `CLLocationCoordinate2D` from an `ExifData` field list.
    ///
    /// Extracts `GPSLatitude`, `GPSLatitudeRef`, `GPSLongitude`, and `GPSLongitudeRef`
    /// by key-suffix match (keys may carry a namespace prefix such as `"{GPS} GPSLatitude"`).
    ///
    /// Returns `nil` if any required field is absent, the ref values are invalid,
    /// the numeric value cannot be parsed, or the resulting coordinate is out of range.
    static func coordinate(from exifData: MetadataEngine.ExifData) -> CLLocationCoordinate2D? {
        // Extract the four required fields by key-suffix match
        guard
            let latStr  = value(for: "GPSLatitude",     in: exifData.fields),
            let latRef  = value(for: "GPSLatitudeRef",  in: exifData.fields),
            let lonStr  = value(for: "GPSLongitude",    in: exifData.fields),
            let lonRef  = value(for: "GPSLongitudeRef", in: exifData.fields)
        else { return nil }

        // Validate hemisphere references
        guard latRef == "N" || latRef == "S" else { return nil }
        guard lonRef == "E" || lonRef == "W" else { return nil }

        // Parse numeric values (DMS or decimal)
        guard
            let latMag = parseNumeric(latStr),
            let lonMag = parseNumeric(lonStr)
        else { return nil }

        // Apply hemisphere sign
        let lat = latRef == "S" ? -latMag : latMag
        let lon = lonRef == "W" ? -lonMag : lonMag

        // Validate coordinate range
        guard lat >= -90.0, lat <= 90.0 else { return nil }
        guard lon >= -180.0, lon <= 180.0 else { return nil }

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Coordinate formatting

    /// Format a coordinate as `"39.7392° N, 104.9903° W"`.
    ///
    /// Latitude zero uses `"N"`; longitude zero uses `"E"`.
    static func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat    = abs(coordinate.latitude)
        let latHem = coordinate.latitude  >= 0 ? "N" : "S"
        let lon    = abs(coordinate.longitude)
        let lonHem = coordinate.longitude >= 0 ? "E" : "W"
        return String(format: "%.4f° %@, %.4f° %@", lat, latHem, lon, lonHem)
    }

    // MARK: - Private helpers

    /// Return the value for the first field whose key has the given suffix.
    private static func value(
        for suffix: String,
        in fields: [(key: String, value: String)]
    ) -> String? {
        fields.first { $0.key == suffix || $0.key.hasSuffix(" \(suffix)") }?.value
    }

    /// Parse a GPS numeric string in either DMS or decimal format.
    ///
    /// DMS format example: `"39 deg 44' 21.16\""`
    /// Decimal format example: `"39.739211"`
    ///
    /// Returns the absolute (unsigned) magnitude; sign is applied by the caller.
    private static func parseNumeric(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Attempt DMS parse first
        // Pattern: (\d+)\s*deg\s*(\d+)'\s*([\d.]+)"
        if let match = try? /(\d+)\s*deg\s*(\d+)'\s*([\d.]+)"/.firstMatch(in: trimmed) {
            guard
                let degrees = Double(match.output.1),
                let minutes = Double(match.output.2),
                let seconds = Double(match.output.3)
            else { return nil }
            let value = degrees + minutes / 60.0 + seconds / 3600.0
            return value
        }

        // Fall back to decimal parse
        return Double(trimmed)
    }
}
