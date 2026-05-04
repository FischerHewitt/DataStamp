import SwiftUI
import MapKit
import CoreLocation

// MARK: - LocationPickerSheet

struct LocationPickerSheet: View {

    /// Called when the user confirms a location.
    var onSelect: (CLLocationCoordinate2D, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // SF default
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )
    @State private var pinCoord: CLLocationCoordinate2D? = nil
    @State private var pinLabel: String = ""
    @State private var searchText: String = ""
    @State private var isGeocoding: Bool = false
    @State private var geocodeError: String? = nil
    @State private var searchResults: [MKMapItem] = []
    @State private var showResults: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pick Location")
                        .font(.headline)
                    Text("Search or click anywhere on the map")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Search bar
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search city, address, landmark…", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { searchLocation() }
                    if isGeocoding {
                        ProgressView().scaleEffect(0.7)
                    } else if !searchText.isEmpty {
                        Button { searchText = ""; searchResults = []; showResults = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if let err = geocodeError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                }

                // Search results dropdown
                if showResults && !searchResults.isEmpty {
                    Divider()
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { item in
                                Button {
                                    selectMapItem(item)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.dsAccent)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.name ?? "Unknown")
                                                .font(.subheadline.weight(.medium))
                                            if let addr = item.placemark.title {
                                                Text(addr)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Map
            ZStack {
                TappableMapView(
                    region: $region,
                    pinCoord: $pinCoord,
                    onTap: { coord in
                        pinCoord = coord
                        reverseGeocode(coord)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if pinCoord == nil {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                        .allowsHitTesting(false)
                }

                // Pin label overlay
                if let label = pinCoord != nil ? pinLabel : nil, !label.isEmpty {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color(red: 0.20, green: 0.72, blue: 0.35))
                            Text(label)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                        )
                        .padding(16)
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if let coord = pinCoord {
                    Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap the map or use the center marker")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.escape)

                Button {
                    confirmSelection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Use This Location").fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [.dsAccent, .dsMid],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
                .accessibilityIdentifier("useLocationButton")
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 580, height: 520)
    }

    // MARK: - Actions

    private func confirmSelection() {
        let coord = pinCoord ?? region.center
        let trimmedLabel = pinLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        onSelect(coord, trimmedLabel.isEmpty ? coordinateLabel(for: coord) : trimmedLabel)
        dismiss()
    }

    private func coordinateLabel(for coord: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
    }

    private func searchLocation() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isGeocoding = true
        geocodeError = nil
        showResults = false

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        MKLocalSearch(request: request).start { response, error in
            DispatchQueue.main.async {
                isGeocoding = false
                if let items = response?.mapItems, !items.isEmpty {
                    searchResults = items
                    showResults = true
                } else {
                    geocodeError = "No results found"
                }
            }
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        DispatchQueue.main.async {
            pinCoord = coord
            pinLabel = item.name ?? item.placemark.title ?? ""
            showResults = false
            searchText = pinLabel
            withAnimation {
                region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude,
                                                        longitude: coord.longitude)) { placemarks, _ in
            DispatchQueue.main.async {
                if let place = placemarks?.first {
                    let parts = [place.name, place.locality, place.country]
                        .compactMap { $0 }
                    pinLabel = parts.prefix(2).joined(separator: ", ")
                } else {
                    pinLabel = String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                }
            }
        }
    }
}

// MARK: - TappableMapView (NSViewRepresentable)

struct TappableMapView: NSViewRepresentable {

    @Binding var region: MKCoordinateRegion
    @Binding var pinCoord: CLLocationCoordinate2D?
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.setRegion(region, animated: false)
        map.showsZoomControls = true
        map.showsCompass = true

        let click = NSClickGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(click)
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self

        // Move map to new region if it changed significantly
        let currentCenter = map.region.center
        let newCenter = region.center
        if abs(currentCenter.latitude - newCenter.latitude) > 0.001 ||
           abs(currentCenter.longitude - newCenter.longitude) > 0.001 {
            map.setRegion(region, animated: true)
        }

        // Update pin annotation
        map.removeAnnotations(map.annotations)
        if let coord = pinCoord {
            let ann = MKPointAnnotation()
            ann.coordinate = coord
            map.addAnnotation(ann)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TappableMapView

        init(_ parent: TappableMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: NSClickGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coord = map.convert(point, toCoordinateFrom: map)
            parent.pinCoord = coord
            parent.onTap(coord)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            view.markerTintColor = NSColor(red: 0.20, green: 0.72, blue: 0.35, alpha: 1)
            view.glyphImage = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)
            return view
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

#Preview {
    LocationPickerSheet { coord, label in
        print("Selected: \(label) at \(coord)")
    }
}
