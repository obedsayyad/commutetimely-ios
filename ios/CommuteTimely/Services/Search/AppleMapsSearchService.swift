//
//  AppleMapsSearchService.swift
//  CommuteTimely
//
//  Native Apple Maps search using MKLocalSearchCompleter and MKLocalSearch
//

import Foundation
import MapKit
import CoreLocation
import Contacts

protocol AppleMapsSearchServiceProtocol {
    func searchPlaces(query: String, region: MKCoordinateRegion?) async throws -> [Location]
    func getCompletions(for query: String, region: MKCoordinateRegion?) async -> [MKLocalSearchCompletion]
}

final class AppleMapsSearchService: NSObject, AppleMapsSearchServiceProtocol {
    private let searchCompleter: MKLocalSearchCompleter
    private var completionContinuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?
    
    override init() {
        searchCompleter = MKLocalSearchCompleter()
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        // Set a default region (San Francisco) as fallback
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
    
    func searchPlaces(query: String, region: MKCoordinateRegion?) async throws -> [Location] {
        guard !query.isEmpty, query.count >= 2 else {
            if AppConfiguration.isDebug {
                print("[AppleMapsSearch] Query too short: '\(query)'")
            }
            return []
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        
        // Smart region detection: check if query suggests international location
        let detectedRegion = determineSearchRegion(query: query, providedRegion: region)
        
        if let detectedRegion = detectedRegion {
            request.region = detectedRegion
            if AppConfiguration.isDebug {
                print("[AppleMapsSearch] Using detected region: center=\(detectedRegion.center.latitude),\(detectedRegion.center.longitude), span=\(detectedRegion.span.latitudeDelta),\(detectedRegion.span.longitudeDelta)")
            }
        } else {
            // For international queries, don't set region to allow global search
            if AppConfiguration.isDebug {
                print("[AppleMapsSearch] No region set - allowing global search for '\(query)'")
            }
        }
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            let locations = response.mapItems.compactMap { mapItem -> Location? in
                guard let coordinate = extractCoordinate(from: mapItem) else {
                    if AppConfiguration.isDebug {
                        print("[AppleMapsSearch] MapItem missing coordinate: \(mapItem.name ?? "unknown")")
                    }
                    return nil
                }
                
                let address = extractAddress(from: mapItem) ?? mapItem.name ?? "Unknown location"
                let placeName = mapItem.name
                
                if AppConfiguration.isDebug {
                    print("[AppleMapsSearch] Found: \(placeName ?? "unnamed") at \(coordinate.latitude),\(coordinate.longitude)")
                }
                
                return Location(
                    coordinate: Coordinate(clCoordinate: coordinate),
                    address: address,
                    placeName: placeName,
                    placeType: mapPlaceType(from: mapItem.pointOfInterestCategory)
                )
            }
            
            if AppConfiguration.isDebug {
                print("[AppleMapsSearch] Query '\(query)' returned \(locations.count) results")
            }
            
            return locations
        } catch {
            if AppConfiguration.isDebug {
                print("[AppleMapsSearch] Error searching '\(query)': \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    func getCompletions(for query: String, region: MKCoordinateRegion?) async -> [MKLocalSearchCompletion] {
        guard !query.isEmpty, query.count >= 2 else {
            return []
        }
        
        // Update completer region if provided
        if let region = region, isValidRegion(region) {
            searchCompleter.region = region
        }
        
        // Update query
        searchCompleter.queryFragment = query
        
        // Wait for results using continuation
        return await withCheckedContinuation { continuation in
            self.completionContinuation = continuation
            // Timeout after 2 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if self.completionContinuation != nil {
                    self.completionContinuation?.resume(returning: [])
                    self.completionContinuation = nil
                }
            }
        }
    }
    
    private func isValidRegion(_ region: MKCoordinateRegion) -> Bool {
        // Ensure span is not too small (minimum 0.01 degrees)
        return region.span.latitudeDelta >= 0.01 && region.span.longitudeDelta >= 0.01
    }
    
    /// Determines the appropriate search region based on query content and provided region
    /// Returns nil for international queries to allow global search
    private func determineSearchRegion(query: String, providedRegion: MKCoordinateRegion?) -> MKCoordinateRegion? {
        let normalizedQuery = query.lowercased()
        
        // Check if query contains international location hints
        if containsInternationalLocationHint(normalizedQuery) {
            // For international queries, use a very broad region or nil to allow global search
            // Using a very large span to cover the world
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
        }
        
        // Use provided region if valid
        if let region = providedRegion, isValidRegion(region) {
            return region
        }
        
        // For local queries without region, use a default (but this should be rare)
        // Only use SF default if query doesn't suggest international location
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
    
    /// Detects if query contains hints for international locations (cities, countries)
    private func containsInternationalLocationHint(_ query: String) -> Bool {
        // Common international city names and country names
        let internationalHints = [
            // Indian cities
            "pune", "mumbai", "delhi", "bangalore", "hyderabad", "chennai", "kolkata",
            "ahmedabad", "jaipur", "surat", "lucknow", "kanpur", "nagpur", "indore",
            // Countries
            "india", "china", "japan", "korea", "thailand", "singapore", "malaysia",
            "indonesia", "philippines", "vietnam", "australia", "new zealand",
            "uk", "united kingdom", "london", "paris", "berlin", "rome", "madrid",
            "moscow", "dubai", "doha", "riyadh", "cairo", "johannesburg",
            "toronto", "vancouver", "montreal", "sydney", "melbourne", "brisbane",
            "sao paulo", "rio", "buenos aires", "mexico city", "lima", "bogota"
        ]
        
        // Check if any hint appears in the query
        return internationalHints.contains { hint in
            query.contains(hint)
        }
    }
    
    private func extractCoordinate(from mapItem: MKMapItem) -> CLLocationCoordinate2D? {
        if #available(iOS 26, *) {
            return mapItem.location.coordinate
        } else {
            return mapItem.placemark.location?.coordinate
        }
    }
    
    private func extractAddress(from mapItem: MKMapItem) -> String? {
        if #available(iOS 26, *) {
            if let address = mapItem.address {
                return address.shortAddress ?? address.fullAddress
            }
            if let representations = mapItem.addressRepresentations,
               let formatted = representations.fullAddress(includingRegion: true, singleLine: true) {
                return formatted
            }
        } else {
            // Legacy iOS < 26
            if let postalAddress = mapItem.placemark.postalAddress {
                let formatter = CNPostalAddressFormatter()
                formatter.style = .mailingAddress
                let formatted = formatter.string(from: postalAddress)
                return formatted.replacingOccurrences(of: "\n", with: ", ")
            }
        }
        return mapItem.placemark.title
    }
    
    private func mapPlaceType(from category: MKPointOfInterestCategory?) -> PlaceType? {
        guard let category = category else { return nil }
        switch category {
        case .school, .university:
            return .school
        case .fitnessCenter:
            return .gym
        case .restaurant, .cafe:
            return .restaurant
        case .store:
            return .shop
        default:
            return .other
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension AppleMapsSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        if AppConfiguration.isDebug {
            print("[AppleMapsSearch] Completer returned \(completer.results.count) completions for '\(completer.queryFragment)'")
        }
        completionContinuation?.resume(returning: completer.results)
        completionContinuation = nil
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        if AppConfiguration.isDebug {
            print("[AppleMapsSearch] Completer error: \(error.localizedDescription)")
        }
        completionContinuation?.resume(returning: [])
        completionContinuation = nil
    }
}

