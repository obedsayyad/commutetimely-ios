//
//  SearchService.swift
//  CommuteTimely
//
//  Debounced, contextual search backed by Mapbox Places plus local signals.
//

import Foundation
import CoreLocation
import MapKit

protocol SearchServiceProtocol {
    func suggestions(
        for query: String,
        userCoordinate: Coordinate?
    ) async throws -> SearchResponse
    
    func recordSelection(_ location: Location)
    func clearRecents()
}

struct SearchResponse {
    let suggestions: [SearchSuggestion]
    let latency: TimeInterval
    let query: String
    let source: SearchResponseSource
    
    enum SearchResponseSource {
        case live
        case cached
    }
}

struct SearchSuggestion: Identifiable, Equatable {
    enum Source: String {
        case favorite
        case recent
        case mapbox
        case nearby
        case droppedPin
    }
    
    let id: UUID
    let title: String
    let subtitle: String
    let iconSystemName: String
    let location: Location
    let travelTimeMinutes: Int?
    let trafficSummary: String?
    let typicalTrafficText: String?
    let source: Source
    
    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        iconSystemName: String,
        location: Location,
        travelTimeMinutes: Int?,
        trafficSummary: String?,
        typicalTrafficText: String?,
        source: Source
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.location = location
        self.travelTimeMinutes = travelTimeMinutes
        self.trafficSummary = trafficSummary
        self.typicalTrafficText = typicalTrafficText
        self.source = source
    }
}

enum SearchError: LocalizedError, Equatable {
    struct WrappedError: Equatable {
        let domain: String
        let code: Int
        let description: String
        
        init(_ error: Error) {
            let nsError = error as NSError
            self.domain = nsError.domain
            self.code = nsError.code
            self.description = error.localizedDescription
        }
    }
    
    case cancelled
    case networkFailure
    case rateLimited
    case noResults
    case underlying(WrappedError)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Search cancelled"
        case .networkFailure:
            return "We couldn’t reach the search service. Check your connection."
        case .rateLimited:
            return "Search is cooling off due to too many requests. Try again shortly."
        case .noResults:
            return "No places matched that query."
        case .underlying(let wrapped):
            return wrapped.description
        }
    }
    
    static func == (lhs: SearchError, rhs: SearchError) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled),
             (.networkFailure, .networkFailure),
             (.rateLimited, .rateLimited),
             (.noResults, .noResults):
            return true
        case let (.underlying(le), .underlying(re)):
            return le == re
        default:
            return false
        }
    }
}

final class SearchService: SearchServiceProtocol {
    private let appleMapsSearchService: AppleMapsSearchServiceProtocol
    private let mapboxService: MapboxServiceProtocol // Keep for routing
    private let tripStorageService: TripStorageServiceProtocol
    private let recentStore: RecentLocationStore
    private let routeCache = NSCache<NSString, RouteInfoBox>()
    private let metricsRecorder: SearchMetricsRecorder
    private let clock: () -> Date
    
    init(
        appleMapsSearchService: AppleMapsSearchServiceProtocol? = nil,
        mapboxService: MapboxServiceProtocol,
        tripStorageService: TripStorageServiceProtocol,
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = Date.init
    ) {
        self.appleMapsSearchService = appleMapsSearchService ?? AppleMapsSearchService()
        self.mapboxService = mapboxService
        self.tripStorageService = tripStorageService
        self.recentStore = RecentLocationStore(userDefaults: userDefaults)
        self.metricsRecorder = SearchMetricsRecorder()
        self.clock = clock
    }
    
    func suggestions(
        for query: String,
        userCoordinate: Coordinate?
    ) async throws -> SearchResponse {
        let startedAt = clock()
        
        if Task.isCancelled {
            throw SearchError.cancelled
        }
        
        var buckets: [[SearchSuggestion]] = []
        
        // 1) contextual suggestions (Home, Work, favorites)
        let contextual = await contextualSuggestions(
            query: query,
            userCoordinate: userCoordinate
        )
        if !contextual.isEmpty {
            buckets.append(contextual)
        }
        
        // 2) local recents
        let recents = recentStore
            .recentLocations(matching: query)
            .map { rec -> SearchSuggestion in
                SearchSuggestion(
                    title: rec.location.displayName,
                    subtitle: rec.location.address,
                    iconSystemName: "clock.arrow.circlepath",
                    location: rec.location,
                    travelTimeMinutes: nil,
                    trafficSummary: "Recent",
                    typicalTrafficText: nil,
                    source: .recent
                )
            }
        if !recents.isEmpty {
            buckets.append(Array(recents.prefix(3)))
        }
        
        // 3) remote places from Apple Maps
        if query.count >= 2 {
            do {
                let remote = try await fetchRemoteSuggestions(
                    for: query,
                    userCoordinate: userCoordinate
                )
                if !remote.isEmpty {
                    buckets.append(remote)
                } else if AppConfiguration.isDebug {
                    print("[SearchService] No remote results for '\(query)', but continuing with local results")
                }
            } catch {
                // For any errors, log but continue with local results
                if AppConfiguration.isDebug {
                    print("[SearchService] Remote search error for '\(query)': \(error.localizedDescription). Continuing with local results.")
                }
                // Don't throw - allow local results to be returned
            }
        }
        
        let flattened = buckets.flatMap { $0 }
        let latency = clock().timeIntervalSince(startedAt)
        
        if flattened.isEmpty {
            metricsRecorder.record(resultCount: 0, latency: latency, query: query)
            throw SearchError.noResults
        }
        
        metricsRecorder.record(resultCount: flattened.count, latency: latency, query: query)
        
        return SearchResponse(
            suggestions: flattened.unique(by: { "\($0.title)|\($0.subtitle)" }),
            latency: latency,
            query: query,
            source: .live
        )
    }
    
    func recordSelection(_ location: Location) {
        recentStore.persist(location: location)
    }
    
    func clearRecents() {
        recentStore.clear()
    }
}

// MARK: - Helpers

private extension SearchService {
    func contextualSuggestions(
        query: String,
        userCoordinate: Coordinate?
    ) async -> [SearchSuggestion] {
        let trips = await tripStorageService.fetchTrips()
        let favorites = trips
            .filter { !$0.tags.isEmpty || $0.destination.placeType == .home || $0.destination.placeType == .work }
            .sorted { $0.createdAt > $1.createdAt }
            .map { trip -> SearchSuggestion in
                let title = trip.customName ?? trip.destination.displayName
                let tagIcon: String
                if trip.tags.contains(.home) || trip.destination.placeType == .home {
                    tagIcon = "house.fill"
                } else if trip.tags.contains(.work) || trip.destination.placeType == .work {
                    tagIcon = "building.2.fill"
                } else {
                    tagIcon = "star.fill"
                }
                return SearchSuggestion(
                    title: title,
                    subtitle: trip.destination.address,
                    iconSystemName: tagIcon,
                    location: trip.destination,
                    travelTimeMinutes: trip.cachedTravelTimeMinutes,
                    trafficSummary: trip.cachedTrafficSummary,
                    typicalTrafficText: trip.typicalTrafficWindowDescription,
                    source: .favorite
                )
            }
        
        guard !favorites.isEmpty else { return [] }
        
        if query.isEmpty {
            return Array(favorites.prefix(4))
        }
        
        let normalizedQuery = preprocessQuery(query).lowercased()
        return favorites.filter { favorite in
            Self.fuzzyMatch(query: normalizedQuery, text: favorite.title.lowercased()) ||
            Self.fuzzyMatch(query: normalizedQuery, text: favorite.subtitle.lowercased())
        }
    }
    
    @MainActor
    func fetchRemoteSuggestions(
        for query: String,
        userCoordinate: Coordinate?
    ) async throws -> [SearchSuggestion] {
        // Preprocess query: normalize and extract location hints
        let preprocessedQuery = preprocessQuery(query)
        
        // Build region from user coordinate or use default
        let region: MKCoordinateRegion?
        if let coord = userCoordinate {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        } else {
            // Default to SF region (will be overridden by smart region detection if international)
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        if AppConfiguration.isDebug {
            print("[SearchService] Searching Apple Maps for '\(preprocessedQuery)' (original: '\(query)') with region: \(region != nil ? "provided" : "default")")
        }
        
        let locations: [Location]
        do {
            locations = try await appleMapsSearchService.searchPlaces(query: preprocessedQuery, region: region)
        } catch {
            if AppConfiguration.isDebug {
                print("[SearchService] Apple Maps search failed: \(error.localizedDescription)")
            }
            throw error
        }
        
        if locations.isEmpty {
            if AppConfiguration.isDebug {
                print("[SearchService] No locations found for '\(query)'")
            }
            return []
        }
        
        let topLocations = Array(locations.prefix(8))
        var suggestions: [(suggestion: SearchSuggestion, score: Double)] = []
        
        let normalizedQuery = preprocessQuery(query).lowercased()
        
        for location in topLocations {
            let routeInfo = try? await routeInfo(
                to: location,
                origin: userCoordinate
            )
            
            let title = location.placeName ?? location.displayName
            let subtitle = location.address
            
            // Calculate relevance score
            let score = calculateRelevanceScore(
                query: normalizedQuery,
                title: title.lowercased(),
                subtitle: subtitle.lowercased(),
                location: location,
                userCoordinate: userCoordinate
            )
            
            let suggestion = SearchSuggestion(
                title: title,
                subtitle: subtitle,
                iconSystemName: "mappin.circle.fill",
                location: location,
                travelTimeMinutes: routeInfo?.durationInMinutes.roundedMinutes(),
                trafficSummary: routeInfo?.congestionLevel.description,
                typicalTrafficText: routeInfo.map { Self.typicalTrafficText(for: $0) },
                source: .mapbox // Keep source name for compatibility
            )
            
            suggestions.append((suggestion: suggestion, score: score))
        }
        
        // Sort by relevance score (highest first), then by travel time
        let sortedSuggestions = suggestions.sorted { lhs, rhs in
            if abs(lhs.score - rhs.score) > 0.1 {
                // Significant score difference - prioritize relevance
                return lhs.score > rhs.score
            } else {
                // Similar scores - use travel time as tiebreaker
                let lhsTime = lhs.suggestion.travelTimeMinutes ?? Int.max
                let rhsTime = rhs.suggestion.travelTimeMinutes ?? Int.max
                return lhsTime < rhsTime
            }
        }
        
        if AppConfiguration.isDebug {
            print("[SearchService] Returning \(sortedSuggestions.count) suggestions for '\(query)'")
            for (index, item) in sortedSuggestions.prefix(3).enumerated() {
                print("[SearchService]   \(index + 1). \(item.suggestion.title) (score: \(String(format: "%.2f", item.score)))")
            }
        }
        
        return sortedSuggestions.map { $0.suggestion }
    }
    
    func routeInfo(
        to location: Location,
        origin: Coordinate?
    ) async throws -> RouteInfo? {
        guard let origin else { return nil }
        let cacheKey = "\(origin.latitude),\(origin.longitude)|\(location.coordinate.latitude),\(location.coordinate.longitude)" as NSString
        
        if let cached = routeCache.object(forKey: cacheKey)?.route {
            return cached
        }
        
        do {
            let route = try await mapboxService.getRoute(
                from: origin,
                to: location.coordinate
            )
            routeCache.setObject(RouteInfoBox(route: route), forKey: cacheKey)
            return route
        } catch {
            return nil
        }
    }
    
    static func typicalTrafficText(for route: RouteInfo) -> String {
        switch route.congestionLevel {
        case .none: return "Wide open roads"
        case .low: return "Light traffic"
        case .moderate: return "Typical slowdown"
        case .heavy: return "Heavy traffic"
        case .severe: return "Gridlock"
        }
    }
    
    func translateNetworkError(_ error: NetworkError) -> SearchError {
        switch error {
        case .rateLimited:
            return .rateLimited
        case .unauthorized, .forbidden:
            return .networkFailure
        case .networkFailed:
            return .networkFailure
        case .notFound:
            return .noResults
        default:
            return .networkFailure
        }
    }
    
    /// Enhanced fuzzy matching that handles typos, word order, and partial matches
    static func fuzzyMatch(query: String, text: String) -> Bool {
        // Exact match
        if text == query {
            return true
        }
        
        // Contains match
        if text.contains(query) {
            return true
        }
        
        // Word-by-word matching (order independent)
        let queryWords = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let textWords = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        if queryWords.isEmpty {
            return false
        }
        
        // Check if all query words appear in text (in any order)
        let allWordsMatch = queryWords.allSatisfy { queryWord in
            textWords.contains { textWord in
                textWord.contains(queryWord) || queryWord.contains(textWord)
            }
        }
        
        if allWordsMatch {
            return true
        }
        
        // Check if most words match (fuzzy threshold: at least 50% of words)
        let matchingWords = queryWords.filter { queryWord in
            textWords.contains { textWord in
                textWord.contains(queryWord) || queryWord.contains(textWord)
            }
        }
        
        let matchRatio = Double(matchingWords.count) / Double(queryWords.count)
        return matchRatio >= 0.5
    }
    
    /// Calculates relevance score for a search result (0.0 to 1.0, higher is better)
    private func calculateRelevanceScore(
        query: String,
        title: String,
        subtitle: String,
        location: Location,
        userCoordinate: Coordinate?
    ) -> Double {
        var score: Double = 0.0
        let queryWords = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // 1. Exact title match (highest priority) - 50 points
        if title == query {
            score += 50.0
        } else if title.contains(query) {
            // Partial title match - 30 points
            score += 30.0
        } else {
            // Check word-by-word matches in title
            let titleWords = title.components(separatedBy: .whitespaces)
            let matchingWords = queryWords.filter { qw in
                titleWords.contains { tw in tw.contains(qw) || qw.contains(tw) }
            }
            if !matchingWords.isEmpty {
                score += Double(matchingWords.count) * 10.0 / Double(queryWords.count)
            }
        }
        
        // 2. Exact subtitle match - 30 points
        if subtitle == query {
            score += 30.0
        } else if subtitle.contains(query) {
            // Partial subtitle match - 15 points
            score += 15.0
        } else {
            // Check word-by-word matches in subtitle
            let subtitleWords = subtitle.components(separatedBy: .whitespaces)
            let matchingWords = queryWords.filter { qw in
                subtitleWords.contains { sw in sw.contains(qw) || qw.contains(sw) }
            }
            if !matchingWords.isEmpty {
                score += Double(matchingWords.count) * 5.0 / Double(queryWords.count)
            }
        }
        
        // 3. Place name match (if available) - 20 points
        if let placeName = location.placeName?.lowercased() {
            if placeName == query {
                score += 20.0
            } else if placeName.contains(query) {
                score += 10.0
            }
        }
        
        // 4. Distance bonus (if user location available) - up to 10 points
        // Closer locations get higher scores
        if let userCoord = userCoordinate {
            let distance = location.coordinate.distance(to: userCoord)
            // Within 5km: 10 points, within 25km: 5 points, within 100km: 2 points
            if distance < 5000 {
                score += 10.0
            } else if distance < 25000 {
                score += 5.0
            } else if distance < 100000 {
                score += 2.0
            }
        }
        
        return min(score, 100.0) // Cap at 100
    }
    
    /// Preprocesses search query: normalizes, trims, and handles common variations
    private func preprocessQuery(_ query: String) -> String {
        var processed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove extra whitespace
        processed = processed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Handle common abbreviations
        let abbreviations: [String: String] = [
            "st": "street",
            "ave": "avenue",
            "blvd": "boulevard",
            "rd": "road",
            "dr": "drive",
            "ct": "court",
            "ln": "lane",
            "pkwy": "parkway",
            "hwy": "highway"
        ]
        
        // Only expand abbreviations if they appear as standalone words (with word boundaries)
        for (abbr, full) in abbreviations {
            let pattern = "\\b\(abbr)\\b"
            processed = processed.replacingOccurrences(
                of: pattern,
                with: full,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return processed
    }
}

// MARK: - Support Types

private final class RouteInfoBox: NSObject {
    let route: RouteInfo
    
    init(route: RouteInfo) {
        self.route = route
    }
}

private struct RecentLocation: Codable, Equatable {
    let location: Location
    let lastUsed: Date
}

private final class RecentLocationStore {
    private let userDefaults: UserDefaults
    private let storageKey = "recent_locations"
    private let maxItems = 10
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var cache: [RecentLocation]
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        self.cache = (try? decoder.decode([RecentLocation].self, from: userDefaults.data(forKey: storageKey) ?? Data())) ?? []
    }
    
    func persist(location: Location) {
        cache.removeAll { $0.location == location }
        cache.insert(RecentLocation(location: location, lastUsed: Date()), at: 0)
        if cache.count > maxItems {
            cache = Array(cache.prefix(maxItems))
        }
        save()
    }
    
    func recentLocations(matching query: String) -> [RecentLocation] {
        if query.isEmpty { return cache }
        let normalizedQuery = query.lowercased()
        return cache.filter {
            SearchService.fuzzyMatch(query: normalizedQuery, text: $0.location.displayName.lowercased()) ||
            SearchService.fuzzyMatch(query: normalizedQuery, text: $0.location.address.lowercased())
        }
    }
    
    func clear() {
        cache.removeAll()
        save()
    }
    
    private func save() {
        if let data = try? encoder.encode(cache) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
}

private final class SearchMetricsRecorder {
    private let queue = DispatchQueue(label: "SearchMetricsRecorder")
    private(set) var rollingLatency: [TimeInterval] = []
    private(set) var rollingCounts: [Int] = []
    private let maxSamples = 25
    
    func record(resultCount: Int, latency: TimeInterval, query: String) {
        queue.async {
            self.rollingLatency.append(latency)
            self.rollingCounts.append(resultCount)
            if self.rollingLatency.count > self.maxSamples {
                self.rollingLatency.removeFirst()
            }
            if self.rollingCounts.count > self.maxSamples {
                self.rollingCounts.removeFirst()
            }
            if AppConfiguration.isDebug {
                let avgLatency = self.rollingLatency.reduce(0, +) / Double(self.rollingLatency.count)
                print("[Search] \(query) in \(String(format: "%.0f", latency * 1000))ms avg \(String(format: "%.0f", avgLatency * 1000))ms")
            }
        }
    }
}

private extension Array {
    func unique<K: Hashable>(by transform: (Element) -> K) -> [Element] {
        var seen = Set<K>()
        var result: [Element] = []
        for element in self {
            let key = transform(element)
            if seen.insert(key).inserted {
                result.append(element)
            }
        }
        return result
    }
}

private extension Double {
    func roundedMinutes() -> Int {
        Int(self.rounded())
    }
}


