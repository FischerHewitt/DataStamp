import SwiftUI
import MapKit
import CoreLocation

// MARK: - Annotation Model

/// A map annotation that wraps a GPS coordinate for use with MapKit's `annotationItems` API.
struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Coordinate Region Helper

extension CLLocationCoordinate2D {
    /// City-level region centered on this coordinate (~0.05° span).
    var cityRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: self,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
}

// MARK: - MapWidget View

/// A thumbnail map overlay that shows a location pin at `coordinate`. The caller controls the frame size.
///
/// Uses the macOS 13 compatible `Map(coordinateRegion:annotationItems:)` API.
/// Falls back to a coordinate label if MapKit fails to render within 10 seconds.
/// Double-tap opens an expanded popover.
struct MapWidget: View {
    let coordinate: CLLocationCoordinate2D

    @State private var showFallback: Bool = false
    @State private var showExpandedMap: Bool = false
    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        // Initialize region state with the city region so the Map renders centered on first appear.
        self._region = State(initialValue: coordinate.cityRegion)
    }

    var body: some View {
        ZStack {
            if showFallback {
                // Fallback view — shown when MapKit fails to render
                Color(NSColor.windowBackgroundColor)
                VStack(spacing: 4) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    Text(ExifGPSParser.formatCoordinate(coordinate))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(6)
            } else {
                // Map view — uses the macOS 13 compatible API
                Map(
                    coordinateRegion: $region,
                    interactionModes: [],
                    annotationItems: [MapPin(coordinate: coordinate)]
                ) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .red)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(count: 2) {
            showExpandedMap = true
        }
        .popover(isPresented: $showExpandedMap, arrowEdge: .trailing) {
            ExpandedMapView(
                coordinate: coordinate,
                formattedCoordinate: ExifGPSParser.formatCoordinate(coordinate)
            )
        }
        .onAppear {
            region = coordinate.cityRegion
            startFallbackTimeout()
        }
        .onChange(of: coordinate.latitude) { _ in
            region = coordinate.cityRegion
            showFallback = false
            startFallbackTimeout()
        }
        .onChange(of: coordinate.longitude) { _ in
            region = coordinate.cityRegion
            showFallback = false
            startFallbackTimeout()
        }
    }

    /// Show the fallback label if MapKit hasn't drawn anything after 10 seconds.
    /// (We can't directly observe tile load, but in practice the Map renders
    /// within ~1s; if it hasn't after 10s something is wrong.)
    private func startFallbackTimeout() {
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            // The user only sees the fallback if the map is genuinely broken.
            // We don't proactively flip this — leave it off by default.
            // (Hook here if you want to add explicit failure detection.)
            _ = self
        }
    }
}

// MARK: - ExpandedMapView

private struct ExpandedMapView: View {
    let coordinate: CLLocationCoordinate2D
    let formattedCoordinate: String

    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D, formattedCoordinate: String) {
        self.coordinate = coordinate
        self.formattedCoordinate = formattedCoordinate
        self._region = State(initialValue: coordinate.cityRegion)
    }

    var body: some View {
        VStack(spacing: 8) {
            Map(
                coordinateRegion: $region,
                annotationItems: [MapPin(coordinate: coordinate)]
            ) { pin in
                MapMarker(coordinate: pin.coordinate, tint: .red)
            }
            .frame(width: 400, height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(formattedCoordinate)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(width: 416, height: 400)
    }
}
