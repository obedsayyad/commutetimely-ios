//
// TripListView.swift
// CommuteTimely
//
// List of saved trips with add/edit functionality
//

import SwiftUI
import Combine

struct TripListView: View {
    @StateObject private var viewModel = DIContainer.shared.makeTripListViewModel()
    @State private var showingAddTrip = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()
                
                if viewModel.trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .navigationTitle("My Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTrip = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignTokens.Colors.primaryFallback())
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                TripPlannerView(mode: .create)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignTokens.Colors.textSecondary.opacity(0.5))
            
            Text("No Trips Yet")
                .font(DesignTokens.Typography.title2)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text("Create your first trip to get started with intelligent leave-time predictions")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            
            CTButton("Create Your First Trip", style: .primary) {
                showingAddTrip = true
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.top, DesignTokens.Spacing.md)
        }
    }
    
    private var tripList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(viewModel.trips) { trip in
                    TripListCell(
                        trip: trip,
                        onToggle: { isActive in
                            viewModel.toggleTripActive(trip, isActive: isActive)
                        },
                        onTap: {
                            viewModel.selectTrip(trip)
                        }
                    )
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }
}

// MARK: - TripListViewModel

@MainActor
class TripListViewModel: BaseViewModel {
    @Published var trips: [Trip] = []
    @Published var selectedTrip: Trip?
    
    private let tripStorageService: TripStorageServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    init(
        tripStorageService: TripStorageServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.tripStorageService = tripStorageService
        self.analyticsService = analyticsService
        super.init()
        
        // Subscribe to trip updates
        tripStorageService.trips
            .sink { [weak self] trips in
                self?.trips = trips
            }
            .store(in: &cancellables)
    }
    
    override func onAppear() {
        Task {
            let fetchedTrips = await tripStorageService.fetchTrips()
            trips = fetchedTrips
        }
    }
    
    func toggleTripActive(_ trip: Trip, isActive: Bool) {
        var updatedTrip = trip
        updatedTrip.isActive = isActive
        
        Task {
            try? await tripStorageService.updateTrip(updatedTrip)
        }
    }
    
    func selectTrip(_ trip: Trip) {
        selectedTrip = trip
    }
    
    func deleteTrip(_ trip: Trip) {
        Task {
            try? await tripStorageService.deleteTrip(id: trip.id)
        }
    }
}

#Preview {
    TripListView()
}

