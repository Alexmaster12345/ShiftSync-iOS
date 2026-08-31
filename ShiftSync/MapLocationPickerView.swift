import SwiftUI
import MapKit
import CoreLocation

struct MapLocationPickerView: View {
    @Binding var isPresented: Bool

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var pickedCoordinate: CLLocationCoordinate2D? = nil
    @State private var resolvedAddress: String = ""
    @State private var isResolving: Bool = false

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapLayer
                bottomPanel
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Pick Workplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.shiftBlue)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                searchBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadExistingPin() }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(searchFocused ? .shiftBlue : .ssTextMuted)
                    .font(.system(size: 15))

                TextField("Search address…", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(.ssTextPrimary)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { searchAddress() }

                if isSearching {
                    ProgressView()
                        .tint(.shiftBlue)
                        .scaleEffect(0.8)
                } else if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.ssTextMuted)
                            .font(.system(size: 15))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(searchFocused ? Color.shiftBlue.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )

            if let error = searchError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.darkBg.opacity(0.95))
    }

    // MARK: - Map

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $mapPosition) {
                if let coord = pickedCoordinate {
                    Marker("Workplace", systemImage: "building.2.fill", coordinate: coord)
                        .tint(Color.shiftBlue)
                }
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { screenPoint in
                guard let coord = proxy.convert(screenPoint, from: .local) else { return }
                pickedCoordinate = coord
                resolvedAddress = ""
                reverseGeocode(coord)
            }
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.ssTextMuted)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if pickedCoordinate == nil {
                hintRow
            } else {
                pickedRow
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.darkCard
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.horizontal, 0)
    }

    private var hintRow: some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.tap")
                .font(.system(size: 24))
                .foregroundColor(.ssTextMuted)
            Text("Tap anywhere on the map to pin your workplace")
                .font(.system(size: 14))
                .foregroundColor(.ssTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var pickedRow: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.shiftBlue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.shiftBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if isResolving {
                        Text("Resolving address…")
                            .font(.system(size: 13))
                            .foregroundColor(.ssTextSecondary)
                    } else if !resolvedAddress.isEmpty {
                        Text(resolvedAddress)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.ssTextPrimary)
                            .lineLimit(2)
                    } else {
                        if let c = pickedCoordinate {
                            Text(String(format: "%.5f, %.5f", c.latitude, c.longitude))
                                .font(.system(size: 13))
                                .foregroundColor(.ssTextSecondary)
                        }
                    }
                    Text("Tap again to move the pin")
                        .font(.system(size: 11))
                        .foregroundColor(.ssTextMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Button(action: confirmSelection) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("Set as Workplace")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.shiftBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Actions

    private func searchAddress() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        searchFocused = false
        searchError = nil
        isSearching = true
        Task {
            defer { isSearching = false }
            guard let request = MKGeocodingRequest(addressString: trimmed) else {
                searchError = "Invalid address."
                return
            }
            do {
                let items = try await request.mapItems
                guard let item = items.first else {
                    searchError = "Address not found. Try adding a city or postcode."
                    return
                }
                let coord = item.location.coordinate
                guard CLLocationCoordinate2DIsValid(coord) else {
                    searchError = "Address not found."
                    return
                }
                pickedCoordinate = coord
                resolvedAddress = trimmed
                mapPosition = .camera(MapCamera(centerCoordinate: coord, distance: 600))
            } catch {
                searchError = "Address not found. Try adding a city or postcode."
            }
        }
    }

    private func loadExistingPin() {
        let lat = AppSettings.shared.workplaceLatitude
        let lon = AppSettings.shared.workplaceLongitude
        guard lat != 0 || lon != 0 else {
            // Default to user's approximate region
            mapPosition = .userLocation(fallback: .automatic)
            return
        }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        pickedCoordinate = coord
        resolvedAddress = AppSettings.shared.workplaceAddress
        mapPosition = .camera(MapCamera(centerCoordinate: coord, distance: 600))
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        isResolving = true
        Task {
            defer { isResolving = false }
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            guard let request = MKReverseGeocodingRequest(location: location) else { return }
            let items = try? await request.mapItems
            if let representations = items?.first?.addressRepresentations,
               let full = representations.fullAddress(includingRegion: true, singleLine: true) {
                resolvedAddress = full
            }
        }
    }

    private func confirmSelection() {
        guard let coord = pickedCoordinate else { return }
        AppSettings.shared.workplaceLatitude  = coord.latitude
        AppSettings.shared.workplaceLongitude = coord.longitude
        if !resolvedAddress.isEmpty {
            AppSettings.shared.workplaceAddress = resolvedAddress
        }
        // Always enable alerts and request permissions when user explicitly sets a location
        AppSettings.shared.locationAlertsEnabled = true
        LocationManager.shared.requestPermissions()
        LocationManager.shared.restoreMonitoring()
        isPresented = false
    }
}

#Preview {
    MapLocationPickerView(isPresented: .constant(true))
}
