//
// MapboxService.swift
// CommuteTimely
//
// Service for Mapbox routing and traffic data
//

import Foundation
import CoreLocation

protocol MapboxServiceProtocol {
    func getRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteInfo
    func searchPlaces(query: String, proximity: Coordinate?) async throws -> [Location]
}

class MapboxService: MapboxServiceProtocol {
    private let networkService: NetworkServiceProtocol
    private let accessToken: String
    private let baseURL = "https://api.mapbox.com"
    
    init(networkService: NetworkServiceProtocol, accessToken: String) {
        self.networkService = networkService
        self.accessToken = accessToken
    }
    
    func getRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteInfo {
        let path = "/directions/v5/mapbox/driving-traffic/\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)"
        
        let queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "geometries", value: "geojson"),
            URLQueryItem(name: "overview", value: "full"),
            URLQueryItem(name: "steps", value: "true"),
            URLQueryItem(name: "annotations", value: "congestion,duration"),
            URLQueryItem(name: "alternatives", value: "true")
        ]
        
        let endpoint = Endpoint(
            baseURL: baseURL,
            path: path,
            method: .get,
            queryItems: queryItems
        )
        
        let response: MapboxDirectionsResponse = try await networkService.request(endpoint)
        
        guard let route = response.routes.first else {
            throw MapboxError.noRouteFound
        }
        
        // Calculate traffic delay
        let trafficDelay = calculateTrafficDelay(route: route)
        
        // Determine congestion level
        let congestionLevel = determineCongestionLevel(route: route)
        
        // Parse alternatives
        let alternatives = response.routes.dropFirst().prefix(2).enumerated().map { index, altRoute in
            AlternativeRoute(
                id: "alt_\(index)",
                distance: altRoute.distance,
                duration: altRoute.duration,
                trafficDelay: calculateTrafficDelay(route: altRoute),
                routeName: "Alternative Route \(index + 1)",
                geometry: RouteGeometry(
                    coordinates: altRoute.geometry.coordinates,
                    type: "LineString"
                )
            )
        }
        
        return RouteInfo(
            distance: route.distance,
            duration: route.duration,
            trafficDelay: trafficDelay,
            geometry: RouteGeometry(
                coordinates: route.geometry.coordinates,
                type: "LineString"
            ),
            incidents: [], // Mapbox doesn't provide incidents in this response
            alternativeRoutes: alternatives,
            congestionLevel: congestionLevel
        )
    }
    
    func searchPlaces(query: String, proximity: Coordinate?) async throws -> [Location] {
        let path = "/geocoding/v5/mapbox.places/\(query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query).json"
        
        var queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "types", value: "address,poi")
        ]
        
        if let proximity = proximity {
            queryItems.append(URLQueryItem(
                name: "proximity",
                value: "\(proximity.longitude),\(proximity.latitude)"
            ))
        }
        
        let endpoint = Endpoint(
            baseURL: baseURL,
            path: path,
            method: .get,
            queryItems: queryItems
        )
        
        let response: MapboxGeocodingResponse = try await networkService.request(endpoint)
        
        return response.features.compactMap { feature in
            guard feature.geometry.coordinates.count == 2 else { return nil }
            
            let longitude = feature.geometry.coordinates[0]
            let latitude = feature.geometry.coordinates[1]
            
            return Location(
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                address: feature.placeName,
                placeName: feature.text
            )
        }
    }
    
    private func calculateTrafficDelay(route: MapboxRoute) -> Double {
        // Estimate traffic delay based on congestion annotations
        let typicalDuration = route.distance / 15.0 // Assume 15 m/s typical speed
        return max(0, route.duration - typicalDuration)
    }
    
    private func determineCongestionLevel(route: MapboxRoute) -> CongestionLevel {
        guard let legs = route.legs.first else { return .none }
        
        // Count congestion segments
        var heavyCount = 0
        var moderateCount = 0
        var totalSegments = 0
        
        for step in legs.steps {
            totalSegments += 1
            if let annotation = step.annotation {
                // This is simplified - actual implementation would analyze congestion data
                if annotation.duration > step.distance / 5.0 { // Very slow
                    heavyCount += 1
                } else if annotation.duration > step.distance / 10.0 { // Moderate
                    moderateCount += 1
                }
            }
        }
        
        let heavyRatio = Double(heavyCount) / Double(max(1, totalSegments))
        let moderateRatio = Double(moderateCount) / Double(max(1, totalSegments))
        
        if heavyRatio > 0.5 { return .severe }
        if heavyRatio > 0.3 { return .heavy }
        if moderateRatio > 0.4 { return .moderate }
        if moderateRatio > 0.2 { return .low }
        return .none
    }
}

// MARK: - Mapbox DTOs

struct MapboxDirectionsResponse: Codable {
    let routes: [MapboxRoute]
    let waypoints: [MapboxWaypoint]
}

struct MapboxRoute: Codable {
    let distance: Double
    let duration: Double
    let geometry: MapboxGeometry
    let legs: [MapboxLeg]
}

struct MapboxGeometry: Codable {
    let coordinates: [[Double]]
    let type: String
}

struct MapboxLeg: Codable {
    let distance: Double
    let duration: Double
    let steps: [MapboxStep]
}

struct MapboxStep: Codable {
    let distance: Double
    let duration: Double
    let annotation: MapboxAnnotation?
}

struct MapboxAnnotation: Codable {
    let duration: Double
}

struct MapboxWaypoint: Codable {
    let name: String
    let location: [Double]
}

struct MapboxGeocodingResponse: Codable {
    let features: [MapboxFeature]
}

struct MapboxFeature: Codable {
    let placeName: String
    let text: String
    let geometry: MapboxPointGeometry
    
    enum CodingKeys: String, CodingKey {
        case placeName = "place_name"
        case text
        case geometry
    }
}

struct MapboxPointGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

// MARK: - Errors

enum MapboxError: LocalizedError {
    case noRouteFound
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No route could be found to your destination"
        case .invalidResponse:
            return "Invalid response from Mapbox"
        }
    }
}

// MARK: - Mock Service

class MockMapboxService: MapboxServiceProtocol {
    func getRoute(from origin: Coordinate, to destination: Coordinate) async throws -> RouteInfo {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Calculate approximate distance (simplified)
        let distance = 15000.0 // 15 km
        let duration = 1200.0 // 20 minutes
        
        return RouteInfo(
            distance: distance,
            duration: duration,
            trafficDelay: 180.0, // 3 minutes of traffic delay
            geometry: nil,
            incidents: [
                TrafficIncident(
                    id: "incident_1",
                    type: .congestion,
                    description: "Heavy traffic on Highway 101",
                    severity: 2,
                    coordinate: origin,
                    startTime: Date(),
                    estimatedClearTime: Date().addingTimeInterval(1800)
                )
            ],
            alternativeRoutes: [
                AlternativeRoute(
                    id: "alt_1",
                    distance: 16000,
                    duration: 1100,
                    trafficDelay: 60,
                    routeName: "Via Secondary Road",
                    geometry: nil
                )
            ],
            congestionLevel: .moderate
        )
    }
    
    func searchPlaces(query: String, proximity: Coordinate?) async throws -> [Location] {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return [
            Location(
                coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
                address: "123 Market St, San Francisco, CA 94103",
                placeName: query
            ),
            Location(
                coordinate: Coordinate(latitude: 37.7849, longitude: -122.4094),
                address: "456 Mission St, San Francisco, CA 94105",
                placeName: "\(query) Alternative"
            )
        ]
    }
}

