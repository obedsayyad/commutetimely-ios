//
// DestinationSearchView.swift
// CommuteTimely
//
// Search and select destination
//

import SwiftUI

struct DestinationSearchView: View {
    @ObservedObject var viewModel: TripPlannerViewModel
    let onNext: () -> Void
    
    @State private var searchText = ""
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Search field
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Where are you going?")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                CTTextField(
                    placeholder: "Search for a place",
                    text: $searchText,
                    icon: "magnifyingglass"
                )
                .onChange(of: searchText) { oldValue, newValue in
                    // Cancel previous debounce task
                    debounceTask?.cancel()
                    
                    // Create new debounce task
                    debounceTask = Task {
                        // Wait 300ms after user stops typing
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        
                        // Check if task was cancelled
                        guard !Task.isCancelled else { return }
                        
                        await performSearch(query: newValue)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Search results
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = searchError {
                VStack(spacing: DesignTokens.Spacing.md) {
                    CTInfoCard(
                        title: "Search Error",
                        message: error,
                        icon: "exclamationmark.triangle.fill",
                        style: .warning
                    )
                    .padding(.horizontal)
                    
                    Button("Try Again") {
                        searchError = nil
                        Task {
                            await performSearch(query: searchText)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(searchResults, id: \.coordinate) { location in
                            LocationResultCell(location: location) {
                                viewModel.selectedDestination = location
                                searchText = location.displayName
                                searchResults = []
                            }
                        }
                    }
                    .padding()
                }
            } else if viewModel.selectedDestination != nil {
                // Selected destination preview
                VStack(spacing: DesignTokens.Spacing.md) {
                    CTInfoCard(
                        title: "Destination Selected",
                        message: viewModel.selectedDestination!.displayName,
                        icon: "checkmark.circle.fill",
                        style: .success
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    CTButton("Continue", style: .primary) {
                        onNext()
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } else {
                // Empty state
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DesignTokens.Colors.textSecondary.opacity(0.5))
                    
                    Text("Search for your destination")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty, query.count >= 2 else {
            searchResults = []
            searchError = nil
            return
        }
        
        isSearching = true
        searchError = nil
        
        do {
            // Get user coordinate if available (for better search results)
            let userCoordinate: Coordinate? = nil // TODO: Get from location service
            searchResults = try await viewModel.searchDestinations(query: query, userCoordinate: userCoordinate)
        } catch {
            searchResults = []
            searchError = "Unable to search. Please check your connection and try again."
        }
        
        isSearching = false
    }
}

struct LocationResultCell: View {
    let location: Location
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignTokens.Colors.primaryFallback())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.displayName)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                    
                    if !location.address.isEmpty && location.address != location.displayName {
                        Text(location.address)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding()
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DestinationSearchView(
        viewModel: DIContainer.shared.makeTripPlannerViewModel(),
        onNext: {}
    )
}

