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
    var isSelectingOrigin: Bool = false
    var onDismiss: (() -> Void)? = nil
    
    @State private var searchText = ""
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(isSelectingOrigin ? "Where are you starting from?" : "Where are you going?")
                    .font(DesignTokens.Typography.title3)
                    .fontWeight(.semibold)
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
                
                // Show selected destination/origin if any
                if let selected = isSelectingOrigin ? viewModel.selectedOrigin.location : viewModel.selectedDestination {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Selected:")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text(selected.displayName)
                                .font(DesignTokens.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button {
                            if isSelectingOrigin {
                                viewModel.selectedOrigin = .currentLocation
                            } else {
                                viewModel.selectedDestination = nil
                            }
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.md)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, DesignTokens.Spacing.sm)
            
            // Calendar Suggestions (Premium Feature)
            if !isSelectingOrigin && !viewModel.calendarSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text("Suggested from Calendar")
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        Spacer()
                        
                        Image(systemName: "calendar")
                            .foregroundColor(DesignTokens.Colors.primaryFallback())
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(viewModel.calendarSuggestions) { suggestion in
                                SuggestionCard(suggestion: suggestion) {
                                    viewModel.useSuggestion(suggestion)
                                    onNext()
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, DesignTokens.Spacing.md)
                    }
                }
            }
            
            Divider()
            
            // Search results or states
            if isSearching {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                    Text("Searching...")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = searchError {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DesignTokens.Colors.warning)
                    
                    Text("Search Error")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(error)
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    CTButton("Try Again", style: .secondary) {
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
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults, id: \.coordinate) { location in
                            LocationResultCell(location: location) {
                                // Select destination/origin and auto-advance
                                if isSelectingOrigin {
                                    viewModel.selectedOrigin = .customLocation(location)
                                } else {
                                    viewModel.selectedDestination = location
                                }
                                searchText = location.displayName
                                searchResults = []
                                
                                // Auto-advance or dismiss
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if isSelectingOrigin {
                                        onDismiss?()
                                    } else {
                                        onNext()
                                    }
                                }
                            }
                            
                            if location.coordinate != searchResults.last?.coordinate {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            } else if viewModel.selectedDestination != nil {
                // Selected destination - ready to continue
                VStack(spacing: DesignTokens.Spacing.xl) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Destination Set!")
                            .font(DesignTokens.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text(isSelectingOrigin ? viewModel.selectedOrigin.displayName : viewModel.selectedDestination!.displayName)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    CTButton(isSelectingOrigin ? "Set Starting Point" : "Continue to Schedule", style: .primary) {
                        if isSelectingOrigin {
                            onDismiss?()
                        } else {
                            onNext()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } else {
                // Empty state
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignTokens.Colors.textSecondary.opacity(0.3))
                    
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Find Your Destination")
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text("Type to search for places, addresses, or landmarks")
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                    }
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

    }
}

struct SuggestionCard: View {
    let suggestion: CalendarEventSuggestion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(formatTime(suggestion.startDate))
                        .font(DesignTokens.Typography.caption)
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
                
                if let loc = suggestion.location {
                    Text(loc)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                        .lineLimit(1)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(width: 160, alignment: .leading)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(DesignTokens.Colors.primaryFallback().opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct LocationResultCell: View {
    let location: Location
    let onSelect: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Add haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onSelect()
        }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primaryFallback().opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: placeIcon)
                        .font(.system(size: 20))
                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.displayName)
                        .font(DesignTokens.Typography.body)
                        .fontWeight(.medium)
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
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(isPressed ? DesignTokens.Colors.surface.opacity(0.5) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var placeIcon: String {
        guard let placeType = location.placeType else {
            return "mappin.circle.fill"
        }
        
        switch placeType {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .school: return "book.fill"
        case .gym: return "figure.run"
        case .restaurant: return "fork.knife"
        case .shop: return "cart.fill"
        case .other: return "mappin.circle.fill"
        }
    }
}

#Preview {
    DestinationSearchView(
        viewModel: DIContainer.shared.makeTripPlannerViewModel(),
        onNext: {}
    )
}

