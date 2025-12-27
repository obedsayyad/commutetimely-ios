//
// MapView.swift
// CommuteTimely
//
// Interactive Apple Maps experience for selecting destinations
//

import SwiftUI
import MapKit
import Combine
import UIKit
import CoreLocation

struct MapScreen: View {
    @StateObject private var viewModel = MapViewModel(
        locationService: DIContainer.shared.locationService,
        searchService: DIContainer.shared.searchService,
        tripStorageService: DIContainer.shared.tripStorageService
    )
    @FocusState private var isSearchFocused: Bool
    @StateObject private var trafficOverlayState = TrafficOverlayState()
    
    var body: some View {
        ZStack(alignment: .top) {
            AppleMapView(
                region: $viewModel.mapRegion,
                destinations: viewModel.destinationPins,
                highlightedDestinationID: viewModel.highlightedDestinationID,
                showsUserLocation: viewModel.shouldShowUserLocation,
                trafficOverlayState: trafficOverlayState
            )
            .ignoresSafeArea()
            .accessibilityLabel("Map")
            .accessibilityHint("Drag to move the map, pinch to zoom in or out")
            
            VStack(spacing: DesignTokens.Spacing.sm) {
                searchBar
                
                if viewModel.shouldShowPermissionBanner {
                    permissionBanner
                }

                if viewModel.showCurrentLocationShortcut {
                    currentLocationQuickAction
                }
                
                if viewModel.isSearching {
                    progressIndicator
                } else if !viewModel.searchResults.isEmpty {
                    resultsList
                } else if let errorMessage = viewModel.searchErrorMessage {
                    searchErrorView(message: errorMessage)
                } else if let emptyState = viewModel.searchEmptyStateMessage {
                    searchEmptyStateView(message: emptyState)
                }
                
                Spacer()
                
                if !viewModel.destinationPins.isEmpty {
                    destinationChips
                    if viewModel.highlightedDestination != nil {
                        destinationDetailButton
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, DesignTokens.Spacing.lg)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .alert("Location Access Needed", isPresented: $viewModel.isShowingPermissionAlert) {
            Button("Open Settings", role: .none) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("I need your location to calculate accurate travel times and remind you when to leave. You can enable this in Settings.")
        }
        .sheet(isPresented: $viewModel.showingNameDialog) {
            destinationNameDialog
        }
        .sheet(item: $viewModel.destinationDetailSelection) { pin in
            DestinationDetailView(pin: pin, userCoordinate: viewModel.currentUserCoordinate)
        }
    }
    
    private var destinationNameDialog: some View {
        NavigationView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Name your destination")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Give this location a custom name")
                        .font(DesignTokens.Typography.footnote)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("Destination name", text: $viewModel.destinationName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding()
                    .background(DesignTokens.Colors.surface)
                    .cornerRadius(DesignTokens.CornerRadius.md)
                
                Spacer()
            }
            .padding()
            .background(DesignTokens.Colors.background)
            .navigationTitle("Add Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelAddDestination()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.confirmAddDestination()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            
            TextField("Search for a destination", text: $viewModel.searchQuery, prompt: nil)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .accessibilityLabel("Search destination")
                .accessibilityHint("Type to search for a location or address")
                .onSubmit {
                    viewModel.performSearch()
                }
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        .overlay(alignment: .trailing) {
            Button {
                viewModel.recenterOnUser()
            } label: {
                Image(systemName: "location.circle.fill")
                    .foregroundStyle(viewModel.hasUserLocation ? DesignTokens.Colors.primaryFallback() : DesignTokens.Colors.textTertiary)
            }
            .padding(.trailing, DesignTokens.Spacing.sm)
            .accessibilityLabel("Recenter on current location")
        }
    }
    
    private var permissionBanner: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "location.slash")
                .foregroundColor(.white)
            Text("Enable location access for a better map experience.")
                .font(DesignTokens.Typography.footnote)
                .foregroundColor(.white)
            Spacer()
            Button("Allow", role: .none) {
                viewModel.requestLocationPermissions()
            }
            .font(DesignTokens.Typography.caption.bold())
            .foregroundColor(.white)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.warning)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
    
    private var progressIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
            Text("Searching live traffic & weather…")
                .font(DesignTokens.Typography.footnote)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }
    
    private var currentLocationQuickAction: some View {
        Button {
            viewModel.useCurrentLocation()
            isSearchFocused = false
        } label: {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primaryFallback().opacity(0.15))
                        .frame(width: 44, height: 44)
                    if viewModel.isFetchingCurrentLocationSelection {
                        ProgressView()
                    } else {
                        Image(systemName: "location.fill")
                            .foregroundStyle(DesignTokens.Colors.primaryFallback())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Use current location")
                        .font(DesignTokens.Typography.subheadline.weight(.semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text(viewModel.currentLocationSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding()
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isFetchingCurrentLocationSelection)
    }
    
    private func searchErrorView(message: String) -> some View {
        CTInfoCard(
            title: "Search Temporarily Unavailable",
            message: message,
            icon: "exclamationmark.triangle.fill",
            style: .warning
        )
        .padding(.horizontal, DesignTokens.Spacing.md)
        .accessibilityLabel("Search error: \(message)")
    }
    
    private func searchEmptyStateView(message: String) -> some View {
        CTInfoCard(
            title: "No Results Found",
            message: message,
            icon: "mappin.slash",
            style: .info
        )
        .padding(.horizontal, DesignTokens.Spacing.md)
        .accessibilityLabel("No search results: \(message)")
    }
    
    private var trafficFreshnessBadge: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Circle()
                .fill(trafficOverlayState.isStale ? DesignTokens.Colors.warning : DesignTokens.Colors.success)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(trafficOverlayState.freshnessDescription)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Spacer()
            Button {
                trafficOverlayState.requestManualRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh traffic overlay")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }
    
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            VStack(spacing: 0) {
                ForEach(viewModel.searchResults) { suggestion in
                    SearchSuggestionRow(
                        suggestion: suggestion,
                        selectAction: {
                            viewModel.selectDestination(suggestion.location)
                            isSearchFocused = false
                        },
                        addAction: {
                            viewModel.addDestination(from: suggestion.location)
                        }
                    )
                    
                    if suggestion.id != viewModel.searchResults.last?.id {
                        Divider()
                    }
                }
            }
        }
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }
    
    private var destinationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(viewModel.destinationPins) { destination in
                    let isHighlighted = viewModel.highlightedDestinationID == destination.id
                    DestinationChipView(
                        destination: destination,
                        isHighlighted: isHighlighted
                    ) {
                        viewModel.focus(on: destination)
                    }
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.surfaceElevated.opacity(0.9))
            .cornerRadius(DesignTokens.CornerRadius.lg)
        }
    }
    
    private var destinationDetailButton: some View {
        Button {
            viewModel.presentHighlightedDestinationDetails()
        } label: {
            HStack {
                Image(systemName: "info.circle")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Destination details")
                        .font(DesignTokens.Typography.subheadline.weight(.semibold))
                    if let highlighted = viewModel.highlightedDestination {
                        Text(highlighted.title)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding()
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.highlightedDestination == nil)
    }
}

// MARK: - View Model

@MainActor
final class MapViewModel: BaseViewModel {
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published private(set) var destinationPins: [MapDestinationPin] = []
    @Published private(set) var highlightedDestinationID: UUID?
    @Published var searchQuery: String = "" {
        didSet { handleSearchQueryChange() }
    }
    @Published var searchResults: [SearchSuggestion] = []
    @Published var isSearching = false
    @Published var searchLatencyDescription: String?
    @Published var searchErrorMessage: String?
    @Published var searchEmptyStateMessage: String?
    @Published private(set) var currentLocationSummary: String
    @Published private(set) var isFetchingCurrentLocationSelection = false
    @Published var shouldShowPermissionBanner = false
    @Published var isShowingPermissionAlert = false
    @Published var showingNameDialog = false
    @Published var pendingLocation: Location?
    @Published var destinationName: String = ""
    @Published var destinationDetailSelection: MapDestinationPin?
    
    var destinations: [MapDestinationPin] { destinationPins }
    var hasUserLocation: Bool { userLocation != nil }
    var shouldShowUserLocation: Bool { hasUserLocation }
    var showCurrentLocationShortcut: Bool {
        userLocation != nil && searchQuery.isEmpty && !isSearching
    }
    var highlightedDestination: MapDestinationPin? {
        guard let highlightedDestinationID else { return nil }
        return destinationPins.first(where: { $0.id == highlightedDestinationID })
    }
    var currentUserCoordinate: Coordinate? { userCoordinate }
    
    private let locationService: LocationServiceProtocol
    private let searchService: SearchServiceProtocol
    private let tripStorageService: TripStorageServiceProtocol
    private var locationCancellable: AnyCancellable?
    private var authorizationCancellable: AnyCancellable?
    private var tripsCancellable: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    private var userLocation: CLLocationCoordinate2D?
    private var currentLocationSuggestion: Location? {
        didSet {
            currentLocationSummary = currentLocationSuggestion?.displayName ?? defaultCurrentLocationSummary
        }
    }
    
    func presentHighlightedDestinationDetails() {
        destinationDetailSelection = highlightedDestination
    }
    private var hasCenteredOnUser = false
    private let defaultCurrentLocationSummary = "Drop a pin where you are"
    private var userCoordinate: Coordinate? {
        guard let userLocation else { return nil }
        return Coordinate(clCoordinate: userLocation)
    }
    private var persistedPins: [MapDestinationPin] = []
    private var transientPins: [MapDestinationPin] = []
    
    init(
        locationService: LocationServiceProtocol,
        searchService: SearchServiceProtocol,
        tripStorageService: TripStorageServiceProtocol
    ) {
        self.locationService = locationService
        self.searchService = searchService
        self.tripStorageService = tripStorageService
        self.currentLocationSummary = defaultCurrentLocationSummary
        super.init()
        bindAuthorizationStatus()
        bindLocationUpdates()
        observeSavedDestinations()
    }
    
    override func onAppear() {
        requestLocationPermissions()
        locationService.startUpdatingLocation()
    }
    
    override func onDisappear() {
        locationService.stopUpdatingLocation()
        super.onDisappear()
    }
    
    func requestLocationPermissions() {
        locationService.requestWhenInUseAuthorization()
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
        searchErrorMessage = nil
        searchLatencyDescription = nil
        searchEmptyStateMessage = nil
    }
    
    func performSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.search(for: self?.searchQuery ?? "")
        }
    }
    
    func recenterOnUser() {
        guard let userLocation else {
            isShowingPermissionAlert = true
            return
        }
        mapRegion = MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    }
    
    func useCurrentLocation() {
        guard let coordinate = userLocation else {
            isShowingPermissionAlert = true
            return
        }

        Task { [weak self] in
            await self?.selectCurrentLocation(at: coordinate)
        }
    }
    
    func selectDestination(_ location: Location) {
        if let pin = existingPin(for: location) {
            highlightedDestinationID = pin.id
            let currentSpan = mapRegion.span
            mapRegion = MKCoordinateRegion(center: pin.coordinate, span: currentSpan)
            searchResults = []
            searchQuery = location.displayName
            searchService.recordSelection(location)
            return
        }
        
        let pin = MapDestinationPin(location: location)
        appendTransientPin(pin)
        highlightedDestinationID = pin.id
        searchQuery = location.displayName
        searchResults = []
        focus(on: pin)
        searchService.recordSelection(location)
    }
    
    func addDestination(from location: Location) {
        // Check if destination already exists
        if existingPin(for: location) != nil {
            return
        }
        
        // Store the location and pre-fill the name
        pendingLocation = location
        destinationName = location.placeName ?? location.address
        showingNameDialog = true
    }
    
    func confirmAddDestination() {
        guard let location = pendingLocation else { return }
        
        // Use custom name if provided, otherwise use default
        let name = destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? nil : name
        
        let pin = MapDestinationPin(location: location, customName: finalName)
        appendTransientPin(pin)
        highlightedDestinationID = pin.id
        focus(on: pin)
        searchService.recordSelection(location)
        
        // Reset dialog state
        cancelAddDestination()
    }
    
    func cancelAddDestination() {
        showingNameDialog = false
        pendingLocation = nil
        destinationName = ""
    }
    
    func focus(on pin: MapDestinationPin) {
        highlightedDestinationID = pin.id
        mapRegion = MKCoordinateRegion(
            center: pin.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }
    
    private func selectCurrentLocation(at coordinate: CLLocationCoordinate2D) async {
        await MainActor.run {
            isFetchingCurrentLocationSelection = true
        }

        defer {
            Task { @MainActor in
                self.isFetchingCurrentLocationSelection = false
            }
        }

        do {
            let location = try await locationService.reverseGeocode(coordinate: coordinate)
            await MainActor.run {
                self.currentLocationSuggestion = location
                self.selectDestination(location)
            }
        } catch {
            let fallback = Location(
                coordinate: Coordinate(clCoordinate: coordinate),
                address: "Current location"
            )
            await MainActor.run {
                self.currentLocationSuggestion = fallback
                self.selectDestination(fallback)
            }
        }
    }
    
    private func updateCurrentLocationSummary(with coordinate: CLLocationCoordinate2D) {
        if let suggestion = currentLocationSuggestion, suggestion.coordinate == Coordinate(clCoordinate: coordinate) {
            currentLocationSummary = suggestion.displayName
        } else {
            let lat = String(format: "%.4f", coordinate.latitude)
            let lon = String(format: "%.4f", coordinate.longitude)
            currentLocationSummary = "Near \(lat), \(lon)"
        }
    }
    
    private func handleSearchQueryChange() {
        guard !searchQuery.isEmpty else {
            // Directly clear state without calling clearSearch() to avoid recursion
            searchTask?.cancel()
            searchResults = []
            isSearching = false
            searchErrorMessage = nil
            searchEmptyStateMessage = nil
            return
        }
        
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            // Debounce: 250ms for smooth typeahead
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.search(for: self?.searchQuery ?? "")
        }
    }
    
    private func search(for query: String) async {
        guard !query.isEmpty, query.count >= 2 else {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
                self.searchEmptyStateMessage = nil
                self.searchErrorMessage = nil
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
            self.searchErrorMessage = nil
            self.searchEmptyStateMessage = nil
        }
        
        do {
            let response = try await searchService.suggestions(
                for: query,
                userCoordinate: userCoordinate
            )
            await MainActor.run {
                self.isSearching = false
                self.searchResults = response.suggestions
                self.searchLatencyDescription = Self.latencyDescription(for: response.latency)
                self.searchEmptyStateMessage = response.suggestions.isEmpty ? "No nearby places matched \"\(query)\". Try a street address or add a pin." : nil
            }
        } catch let error as SearchError {
            await MainActor.run {
                self.isSearching = false
                self.searchLatencyDescription = nil
                
                // Only show error if we truly have no results and query is meaningful
                if error == .noResults && query.count >= 2 {
                    self.searchResults = []
                    self.searchErrorMessage = nil
                    self.searchEmptyStateMessage = "No places matched \"\(query)\". Try a different search term."
                } else if error == .networkFailure {
                    // Network errors: show message but don't block - local results may still be available
                    self.searchErrorMessage = "Search is temporarily unavailable. Showing your saved locations instead."
                    self.searchEmptyStateMessage = nil
                } else {
                    self.searchResults = []
                    self.searchErrorMessage = error.errorDescription
                    self.searchEmptyStateMessage = nil
                }
            }
        } catch {
            if AppConfiguration.isDebug {
                print("[MapViewModel] Search error for '\(query)': \(error.localizedDescription)")
            }
            await MainActor.run {
                self.isSearching = false
                self.searchResults = []
                self.searchLatencyDescription = nil
                // Only show error for meaningful queries
                if query.count >= 2 {
                    self.searchErrorMessage = "I couldn't search right now. Please try again in a moment."
                    self.searchEmptyStateMessage = nil
                } else {
                    self.searchErrorMessage = nil
                    self.searchEmptyStateMessage = nil
                }
            }
        }
    }
    
    private static func latencyDescription(for latency: TimeInterval) -> String? {
        guard latency > 0 else { return nil }
        if latency < 1 {
            return "\(Int(latency * 1000)) ms"
        } else {
            return "\(String(format: "%.1f", latency)) s"
        }
    }
    
    private func bindAuthorizationStatus() {
        authorizationCancellable = locationService.authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.shouldShowPermissionBanner = status == .denied || status == .restricted
            }
    }
    
    private func bindLocationUpdates() {
        locationCancellable = locationService.currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let coordinate = location?.coordinate else { return }
                self?.userLocation = coordinate
                self?.shouldShowPermissionBanner = false
                self?.updateCurrentLocationSummary(with: coordinate)
                guard let self else { return }
                if !self.hasCenteredOnUser {
                    let currentSpan = self.mapRegion.span
                    self.mapRegion = MKCoordinateRegion(center: coordinate, span: currentSpan)
                    self.hasCenteredOnUser = true
                }
            }
    }
    
    private func observeSavedDestinations() {
        tripsCancellable = tripStorageService.trips
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trips in
                guard let self else { return }
                let sorted = trips.sorted { $0.createdAt < $1.createdAt }
                self.persistedPins = sorted.map {
                    MapDestinationPin(
                        id: $0.id,
                        location: $0.destination,
                        customName: $0.customName,
                        tripID: $0.id,
                        tags: $0.tags
                    )
                }
                self.removeTransientDuplicates()
                self.publishPins()
            }
    }
    
    private func existingPin(for location: Location) -> MapDestinationPin? {
        destinationPins.first { $0.location == location }
    }
    
    private func appendTransientPin(_ pin: MapDestinationPin) {
        guard existingPin(for: pin.location) == nil else { return }
        transientPins.append(pin)
        publishPins()
    }
    
    private func removeTransientDuplicates() {
        transientPins.removeAll { transient in
            persistedPins.contains(where: { $0.location == transient.location })
        }
    }
    
    private func publishPins() {
        var combined = persistedPins
        for transient in transientPins {
            if !combined.contains(where: { $0.location == transient.location }) {
                combined.append(transient)
            }
        }
        destinationPins = combined
        reconcileHighlightedDestination()
    }
    
    private func reconcileHighlightedDestination() {
        guard let currentID = highlightedDestinationID else { return }
        if destinationPins.contains(where: { $0.id == currentID }) {
            return
        }
        if let transient = transientPins.first(where: { $0.id == currentID }),
           let replacement = destinationPins.first(where: { $0.location == transient.location }) {
            highlightedDestinationID = replacement.id
        } else if destinationPins.isEmpty {
            highlightedDestinationID = nil
        }
    }
}

// MARK: - Destination Model

struct MapDestinationPin: Identifiable, Hashable {
    let id: UUID
    let location: Location
    let customName: String?
    let tripID: UUID?
    let tags: Set<DestinationTag>
    
    init(
        id: UUID = UUID(),
        location: Location,
        customName: String? = nil,
        tripID: UUID? = nil,
        tags: Set<DestinationTag> = []
    ) {
        self.id = id
        self.location = location
        self.customName = customName
        self.tripID = tripID
        self.tags = tags
    }
    
    var coordinate: CLLocationCoordinate2D { location.coordinate.clLocation }
    var title: String { customName ?? location.placeName ?? location.address }
    var iconName: String {
        if tags.contains(.home) || location.placeType == .home {
            return "house.fill"
        }
        if tags.contains(.work) || location.placeType == .work {
            return "briefcase.fill"
        }
        switch location.placeType {
        case .school: return "graduationcap.fill"
        case .gym: return "figure.run.circle"
        case .restaurant: return "fork.knife"
        case .shop: return "bag.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MapDestinationPin, rhs: MapDestinationPin) -> Bool {
        lhs.id == rhs.id
    }
}

private struct DestinationChipView: View {
    let destination: MapDestinationPin
    let isHighlighted: Bool
    let tapAction: () -> Void
    
    var body: some View {
        Button(action: tapAction) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: destination.iconName)
                Text(destination.title)
                    .font(DesignTokens.Typography.footnote.bold())
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                isHighlighted ?
                    DesignTokens.Colors.primaryFallback().opacity(0.15) :
                    DesignTokens.Colors.surface
            )
            .foregroundColor(
                isHighlighted ?
                    DesignTokens.Colors.primaryFallback() :
                    DesignTokens.Colors.textPrimary
            )
            .cornerRadius(DesignTokens.CornerRadius.round)
        }
        .buttonStyle(.plain)
    }
}

private struct SearchSuggestionRow: View {
    let suggestion: SearchSuggestion
    let selectAction: () -> Void
    let addAction: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: selectAction) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: suggestion.iconSystemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.primaryFallback())
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(DesignTokens.Typography.subheadline.weight(.semibold))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .lineLimit(1)
                        Text(suggestion.subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .lineLimit(2)
                        
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            if let eta = suggestion.travelTimeMinutes {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text("\(eta) min")
                                        .font(DesignTokens.Typography.caption.weight(.semibold))
                                }
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            }
                            
                            if let summary = suggestion.trafficSummary {
                                Text(summary)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                            
                            if let freshness = suggestion.typicalTrafficText {
                                Text(freshness)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                            }
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double tap to preview route")
            
            Button(action: addAction) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(DesignTokens.Colors.primaryFallback())
                    .font(.system(size: 24))
                    .padding(.trailing, DesignTokens.Spacing.md)
                    .accessibilityLabel("Save \(suggestion.title)")
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Map Wrapper

struct AppleMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var destinations: [MapDestinationPin]
    var highlightedDestinationID: UUID?
    var showsUserLocation: Bool
    var trafficOverlayState: TrafficOverlayState
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Coordinator.annotationReuseIdentifier
        )
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
        context.coordinator.configure(mapView: mapView)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        
        if shouldUpdateRegion(current: mapView.region, target: region) {
            mapView.setRegion(region, animated: true)
        }
        
        if mapView.showsUserLocation != showsUserLocation {
            mapView.showsUserLocation = showsUserLocation
        }
        
        context.coordinator.scheduleAnnotationUpdate(
            destinations: destinations,
            highlightedID: highlightedDestinationID,
            mapView: mapView
        )
        context.coordinator.refreshTrafficIfNeeded()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    private func shouldUpdateRegion(
        current: MKCoordinateRegion,
        target: MKCoordinateRegion
    ) -> Bool {
        abs(current.center.latitude - target.center.latitude) > 0.0001 ||
        abs(current.center.longitude - target.center.longitude) > 0.0001
    }
    
    final class Coordinator: NSObject, MKMapViewDelegate {
        static let annotationReuseIdentifier = "destinationAnnotation"
        
        var parent: AppleMapView
        private var currentAnnotations: [UUID: MKPointAnnotation] = [:]
        private weak var mapView: MKMapView?
        private var pendingDestinations: [MapDestinationPin] = []
        private var pendingHighlightedID: UUID?
        private var needsAnnotationRefresh = false
        private lazy var displayLink: CADisplayLink = {
            let link = CADisplayLink(target: self, selector: #selector(flushPendingAnnotationUpdates))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            return link
        }()
        private let trafficController: TrafficOverlayController
        
        init(parent: AppleMapView) {
            self.parent = parent
            self.trafficController = TrafficOverlayController(state: parent.trafficOverlayState)
            super.init()
            _ = displayLink
        }
        
        deinit {
            displayLink.invalidate()
        }
        
        func configure(mapView: MKMapView) {
            self.mapView = mapView
            trafficController.attachIfNeeded(to: mapView)
        }
        
        func scheduleAnnotationUpdate(
            destinations: [MapDestinationPin],
            highlightedID: UUID?,
            mapView: MKMapView
        ) {
            self.mapView = mapView
            pendingDestinations = destinations
            pendingHighlightedID = highlightedID
            needsAnnotationRefresh = true
        }
        
        func refreshTrafficIfNeeded() {
            trafficController.refreshIfNeeded()
        }
        
        @objc private func flushPendingAnnotationUpdates() {
            guard needsAnnotationRefresh, let mapView else { return }
            needsAnnotationRefresh = false
            
            let destinations = pendingDestinations
            let highlightedID = pendingHighlightedID
            
            let idsToRemove = Set(currentAnnotations.keys).subtracting(destinations.map(\.id))
            idsToRemove.forEach { id in
                if let annotation = currentAnnotations[id] {
                    mapView.removeAnnotation(annotation)
                    currentAnnotations.removeValue(forKey: id)
                }
            }
            
            for destination in destinations {
                if let annotation = currentAnnotations[destination.id] {
                    annotation.coordinate = destination.coordinate
                    annotation.title = destination.title
                    annotation.subtitle = destination.location.address
                } else {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = destination.coordinate
                    annotation.title = destination.title
                    annotation.subtitle = destination.location.address
                    mapView.addAnnotation(annotation)
                    currentAnnotations[destination.id] = annotation
                }
            }
            
            if let highlightedID,
               let annotation = currentAnnotations[highlightedID] {
                mapView.selectAnnotation(annotation, animated: true)
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            Task { @MainActor in
                parent.region = mapView.region
            }
            // Schedule traffic refresh separately to avoid publishing during view updates
            Task { @MainActor in
                trafficController.refreshIfNeeded()
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = Self.annotationReuseIdentifier
            let markerView: MKMarkerAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                dequeued.annotation = annotation
                markerView = dequeued
            } else {
                markerView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            
            markerView.animatesWhenAdded = true
            markerView.canShowCallout = true
            markerView.clusteringIdentifier = "destinationCluster"
            markerView.titleVisibility = .visible
            markerView.subtitleVisibility = .adaptive
            markerView.displayPriority = .required
            markerView.glyphTintColor = UIColor.white
            markerView.markerTintColor = UIColor(DesignTokens.Colors.primaryFallback())
            
            return markerView
        }
    }
}

#Preview {
    MapScreen()
}


