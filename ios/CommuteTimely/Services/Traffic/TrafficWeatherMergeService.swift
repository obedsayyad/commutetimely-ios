//
//  TrafficWeatherMergeService.swift
//  CommuteTimely
//
//  Merges Mapbox traffic snapshots with Weatherbit data and caches results.
//

import Foundation

protocol TrafficWeatherMergeServiceProtocol {
    func snapshot(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date
    ) async throws -> TrafficWeatherSnapshot
}

struct TrafficWeatherSnapshot {
    let route: RouteInfo
    let weather: WeatherData
    let heuristicsDelay: TimeInterval
    let generatedAt: Date
    let explanation: String
    let confidence: Double
    
    var leaveTimeAdjustment: TimeInterval {
        heuristicsDelay
    }
}

final class TrafficWeatherMergeService: TrafficWeatherMergeServiceProtocol {
    private let mapboxService: MapboxServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let cacheTTL: TimeInterval
    private let cache = NSCache<NSString, SnapshotBox>()
    private let queue = DispatchQueue(label: "TrafficWeatherMergeService")
    
    init(
        mapboxService: MapboxServiceProtocol,
        weatherService: WeatherServiceProtocol,
        cacheTTL: TimeInterval = 90
    ) {
        self.mapboxService = mapboxService
        self.weatherService = weatherService
        self.cacheTTL = cacheTTL
    }
    
    func snapshot(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date
    ) async throws -> TrafficWeatherSnapshot {
        let cacheKey = cacheKey(origin: origin, destination: destination, arrivalTime: arrivalTime)
        if let cached = cachedSnapshot(for: cacheKey) {
            return cached
        }
        
        // Try to fetch both route and weather, with fallbacks
        var routeInfo: RouteInfo?
        var weather: WeatherData?
        var routeError: Error?
        var weatherError: Error?
        
        // Fetch route (Mapbox)
        do {
            routeInfo = try await mapboxService.getRoute(from: origin, to: destination)
        } catch {
            routeError = error
            print("[TrafficWeather] Mapbox route fetch failed: \(error.localizedDescription)")
            // Try to use cached route if available
            if let cached = cachedSnapshot(for: cacheKey) {
                routeInfo = cached.route
            }
        }
        
        // Fetch weather (Weatherbit)
        do {
            weather = try await weatherService.getCurrentWeather(at: destination)
        } catch {
            weatherError = error
            print("[TrafficWeather] Weatherbit fetch failed: \(error.localizedDescription)")
            // Try to use cached weather if available
            if let cached = cachedSnapshot(for: cacheKey) {
                weather = cached.weather
            }
        }
        
        // Fallback logic: if both failed, use static estimates
        if routeInfo == nil && weather == nil {
            print("[TrafficWeather] Both Mapbox and Weatherbit unavailable, using static fallback")
            let estimatedDistance = origin.distance(to: destination)
            let estimatedDuration = estimatedDistance / 13.0 // ~13 m/s average speed
            routeInfo = RouteInfo(
                distance: estimatedDistance,
                duration: estimatedDuration,
                trafficDelay: estimatedDuration * 0.2, // 20% traffic delay estimate
                geometry: nil,
                incidents: [],
                alternativeRoutes: [],
                congestionLevel: .moderate
            )
            weather = WeatherData(
                temperature: 20,
                feelsLike: 20,
                conditions: .partlyCloudy,
                precipitation: 0,
                precipitationProbability: 10,
                windSpeed: 5,
                windDirection: 180,
                visibility: 10,
                humidity: 60,
                pressure: 1013,
                uvIndex: 3,
                cloudCoverage: 20,
                timestamp: Date(),
                alerts: []
            )
        } else if routeInfo == nil {
            // Mapbox offline, use last cached route or static estimate
            print("[TrafficWeather] Mapbox offline, using fallback route")
            let estimatedDistance = origin.distance(to: destination)
            let estimatedDuration = estimatedDistance / 13.0
            routeInfo = RouteInfo(
                distance: estimatedDistance,
                duration: estimatedDuration,
                trafficDelay: estimatedDuration * 0.2,
                geometry: nil,
                incidents: [],
                alternativeRoutes: [],
                congestionLevel: .moderate
            )
        } else if weather == nil {
            // Weatherbit unavailable, use traffic-only model
            print("[TrafficWeather] Weatherbit unavailable, using traffic-only model")
            weather = WeatherData(
                temperature: 20,
                feelsLike: 20,
                conditions: .partlyCloudy,
                precipitation: 0,
                precipitationProbability: 10,
                windSpeed: 5,
                windDirection: 180,
                visibility: 10,
                humidity: 60,
                pressure: 1013,
                uvIndex: 3,
                cloudCoverage: 20,
                timestamp: Date(),
                alerts: []
            )
        }
        
        guard let finalRoute = routeInfo, let finalWeather = weather else {
            throw TrafficWeatherError.bothServicesUnavailable
        }
        
        let heuristics = heuristicsDelay(route: finalRoute, weather: finalWeather)
        let explanation = buildExplanation(
            route: finalRoute,
            weather: finalWeather,
            heuristics: heuristics,
            routeError: routeError,
            weatherError: weatherError
        )
        let confidence = confidenceScore(route: finalRoute, weather: finalWeather, routeError: routeError, weatherError: weatherError)
        
        let snapshot = TrafficWeatherSnapshot(
            route: finalRoute,
            weather: finalWeather,
            heuristicsDelay: heuristics,
            generatedAt: Date(),
            explanation: explanation,
            confidence: confidence
        )
        
        cacheSnapshot(snapshot, key: cacheKey)
        return snapshot
    }
    
    private func cacheKey(origin: Coordinate, destination: Coordinate, arrivalTime: Date) -> NSString {
        let bucket = Int(arrivalTime.timeIntervalSince1970 / 300) // 5-minute buckets
        return NSString(string: "\(origin.latitude),\(origin.longitude)|\(destination.latitude),\(destination.longitude)|\(bucket)")
    }
    
    private func cachedSnapshot(for key: NSString) -> TrafficWeatherSnapshot? {
        queue.sync {
            guard let box = cache.object(forKey: key),
                  Date().timeIntervalSince(box.snapshot.generatedAt) < cacheTTL else {
                cache.removeObject(forKey: key)
                return nil
            }
            return box.snapshot
        }
    }
    
    private func cacheSnapshot(_ snapshot: TrafficWeatherSnapshot, key: NSString) {
        queue.async {
            self.cache.setObject(SnapshotBox(snapshot: snapshot), forKey: key)
        }
    }
    
    private func heuristicsDelay(route: RouteInfo, weather: WeatherData) -> TimeInterval {
        var delay = route.trafficDelay
        
        switch weather.conditions.impactOnTravel {
        case .none:
            break
        case .minor:
            delay += 120
        case .moderate:
            delay += 240
        case .major:
            delay += 420
        case .severe:
            delay += 600
        }
        
        if weather.windSpeed > 12 {
            delay += 120
        }
        if weather.visibility < 5 {
            delay += 180
        }
        return delay
    }
    
    private func buildExplanation(
        route: RouteInfo,
        weather: WeatherData,
        heuristics: TimeInterval,
        routeError: Error? = nil,
        weatherError: Error? = nil
    ) -> String {
        var parts: [String] = []
        
        if routeError != nil {
            parts.append("using cached route data")
        } else {
            parts.append(route.congestionLevel.description)
        }
        
        if weatherError != nil {
            parts.append("weather data unavailable")
        } else {
            if heuristics > 0 {
                parts.append("weather adds \(Int(heuristics / 60)) min")
            }
            parts.append(weather.conditions.description)
        }
        
        return parts.joined(separator: ", ")
    }
    
    private func confidenceScore(
        route: RouteInfo,
        weather: WeatherData,
        routeError: Error? = nil,
        weatherError: Error? = nil
    ) -> Double {
        var confidence = 0.9
        
        // Reduce confidence if services failed
        if routeError != nil {
            confidence -= 0.3 // Significant reduction for missing traffic data
        }
        if weatherError != nil {
            confidence -= 0.15 // Moderate reduction for missing weather
        }
        
        switch route.congestionLevel {
        case .heavy: confidence -= 0.15
        case .severe: confidence -= 0.25
        default: break
        }
        
        if weather.conditions.impactOnTravel == .major {
            confidence -= 0.1
        } else if weather.conditions.impactOnTravel == .severe {
            confidence -= 0.2
        }
        
        return max(0.3, confidence)
    }
}

// MARK: - Errors

enum TrafficWeatherError: LocalizedError {
    case bothServicesUnavailable
    
    var errorDescription: String? {
        switch self {
        case .bothServicesUnavailable:
            return "Both Mapbox and Weatherbit services are unavailable. Using fallback estimates."
        }
    }
}

private final class SnapshotBox: NSObject {
    let snapshot: TrafficWeatherSnapshot
    
    init(snapshot: TrafficWeatherSnapshot) {
        self.snapshot = snapshot
    }
}

final class MockTrafficWeatherMergeService: TrafficWeatherMergeServiceProtocol {
    func snapshot(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date
    ) async throws -> TrafficWeatherSnapshot {
        let route = RouteInfo(
            distance: 15000,
            duration: 1200,
            trafficDelay: 180,
            geometry: nil,
            incidents: [],
            alternativeRoutes: [],
            congestionLevel: .moderate
        )
        let weather = WeatherData(
            temperature: 20,
            feelsLike: 20,
            conditions: .partlyCloudy,
            precipitation: 0,
            precipitationProbability: 10,
            windSpeed: 5,
            windDirection: 180,
            visibility: 10,
            humidity: 60,
            pressure: 1013,
            uvIndex: 3,
            cloudCoverage: 20,
            timestamp: Date(),
            alerts: []
        )
        return TrafficWeatherSnapshot(
            route: route,
            weather: weather,
            heuristicsDelay: 120,
            generatedAt: Date(),
            explanation: "Moderate traffic, light breeze",
            confidence: 0.85
        )
    }
}

