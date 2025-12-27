//
// LocationService.swift
// CommuteTimely
//
// Location service for managing user location and permissions
//

import Foundation
import CoreLocation
import Combine
import MapKit
import Contacts

protocol LocationServiceProtocol {
    var currentLocation: AnyPublisher<CLLocation?, Never> { get }
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> { get }
    
    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func enableBackgroundLocationIfNeeded()
    func geocode(address: String) async throws -> [Location]
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> Location
}

class LocationService: NSObject, LocationServiceProtocol {
    private let locationManager = CLLocationManager()
    
    private let currentLocationSubject = CurrentValueSubject<CLLocation?, Never>(nil)
    private let authorizationStatusSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.notDetermined)
    
    var currentLocation: AnyPublisher<CLLocation?, Never> {
        currentLocationSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        // Only enable background updates if we have proper authorization
        // This will be set conditionally based on authorization status
        locationManager.pausesLocationUpdatesAutomatically = true
        
        authorizationStatusSubject.send(locationManager.authorizationStatus)
    }
    
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func enableBackgroundLocationIfNeeded() {
        // Only enable background updates if authorized and we need it
        guard locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        // This will only be called when user actively starts a trip
        locationManager.allowsBackgroundLocationUpdates = true
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func geocode(address: String) async throws -> [Location] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.compactMap { mapItem in
            guard let coordinate = mapItemCoordinate(mapItem) else {
                return nil
            }
            
            return Location(
                coordinate: Coordinate(clCoordinate: coordinate),
                address: formattedAddress(from: mapItem) ?? address,
                placeName: mapItem.name,
                placeType: mapPlaceType(from: mapItem.pointOfInterestCategory)
            )
        }
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> Location {
        let request = MKLocalSearch.Request()
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearestItem = response.mapItems.compactMap { item -> (MKMapItem, CLLocationDistance)? in
            guard let itemCoordinate = mapItemCoordinate(item) else {
                return nil
            }
            let itemLocation = CLLocation(latitude: itemCoordinate.latitude, longitude: itemCoordinate.longitude)
            return (item, itemLocation.distance(from: targetLocation))
        }.min(by: { $0.1 < $1.1 })?.0
        
        guard let mapItem = nearestItem else {
            throw NSError(
                domain: "LocationService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No location found"]
            )
        }
        
        return Location(
            coordinate: Coordinate(clCoordinate: mapItemCoordinate(mapItem) ?? coordinate),
            address: formattedAddress(from: mapItem) ?? "Dropped Pin",
            placeName: mapItem.name,
            placeType: mapPlaceType(from: mapItem.pointOfInterestCategory)
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocationSubject.send(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatusSubject.send(manager.authorizationStatus)
        // Don't automatically enable background updates here
        // Let it be enabled only when needed via enableBackgroundLocationIfNeeded()
    }
}

// MARK: - Map Helpers

private extension LocationService {
    func mapItemCoordinate(_ mapItem: MKMapItem) -> CLLocationCoordinate2D? {
        if #available(iOS 26, *) {
            return mapItem.location.coordinate
        } else {
            return mapItem.placemark.location?.coordinate
        }
    }
    
    func formattedAddress(from mapItem: MKMapItem) -> String? {
        if #available(iOS 26, *) {
            if let address = mapItem.address {
                return address.shortAddress ?? address.fullAddress
            }
            if let representations = mapItem.addressRepresentations,
               let formatted = representations.fullAddress(includingRegion: true, singleLine: true) {
                return formatted
            }
            return mapItem.name
        } else {
            return legacyFormattedAddress(from: mapItem.placemark)
        }
    }
    
    @available(iOS, deprecated: 26)
    func legacyFormattedAddress(from placemark: MKPlacemark) -> String? {
        if let postalAddress = placemark.postalAddress {
            let formatted = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
            return formatted.replacingOccurrences(of: "\n", with: ", ")
        }
        return placemark.title
    }
    
    func mapPlaceType(from category: MKPointOfInterestCategory?) -> PlaceType? {
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
        case .airport:
            return .other
        default:
            let identifier = category.rawValue.lowercased()
            if identifier.contains("shop") || identifier.contains("mall") {
                return .shop
            }
            if identifier.contains("train") || identifier.contains("transit") {
                return .other
            }
            return .other
        }
    }
}

// MARK: - Mock Service

class MockLocationService: LocationServiceProtocol {
    var currentLocation: AnyPublisher<CLLocation?, Never> {
        Just(CLLocation(latitude: 37.7749, longitude: -122.4194)).eraseToAnyPublisher()
    }
    
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> {
        Just(.authorizedAlways).eraseToAnyPublisher()
    }
    
    func requestWhenInUseAuthorization() {}
    func requestAlwaysAuthorization() {}
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
    func enableBackgroundLocationIfNeeded() {}
    
    func geocode(address: String) async throws -> [Location] {
        return [Location(
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
            address: address,
            placeName: "Mock Location"
        )]
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> Location {
        return Location(
            coordinate: Coordinate(clCoordinate: coordinate),
            address: "123 Mock St, San Francisco, CA",
            placeName: "Mock Location"
        )
    }
}

