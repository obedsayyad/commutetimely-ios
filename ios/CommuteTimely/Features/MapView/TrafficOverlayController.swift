//
//  TrafficOverlayController.swift
//  CommuteTimely
//
//  Handles Mapbox traffic tiles, caching, and freshness tracking.
//

import Foundation
import MapKit
import Combine

@MainActor
final class TrafficOverlayState: ObservableObject {
    @Published var freshnessDescription: String = "Traffic updating…"
    @Published var isStale: Bool = false
    fileprivate var manualRefreshHandler: (() -> Void)?
    
    func update(with date: Date) {
        let delta = Date().timeIntervalSince(date)
        if delta < 5 {
            freshnessDescription = "Traffic updated just now"
            isStale = false
        } else if delta < 60 {
            freshnessDescription = "Traffic updated \(Int(delta))s ago"
            isStale = false
        } else {
            freshnessDescription = "Traffic data \(Int(delta / 60))m old"
            isStale = delta > 120
        }
    }
    
    func requestManualRefresh() {
        manualRefreshHandler?()
    }
}

final class TrafficOverlayController {
    private weak var mapView: MKMapView?
    private var overlay: MKTileOverlay?
    private var lastRefreshDate: Date = .distantPast
    private let refreshThrottle: TimeInterval = 30
    private let state: TrafficOverlayState
    private var staleTimer: Timer?
    
    init(state: TrafficOverlayState) {
        self.state = state
    }
    
    func attachIfNeeded(to mapView: MKMapView) {
        self.mapView = mapView
        guard overlay == nil else { return }
        
        let overlay = MapboxTrafficTileOverlay(accessToken: AppConfiguration.mapboxAccessToken)
        overlay.minimumZ = 3
        overlay.maximumZ = 17
        overlay.canReplaceMapContent = false
        mapView.addOverlay(overlay, level: .aboveRoads)
        self.overlay = overlay
        Task { @MainActor [weak state] in
            state?.manualRefreshHandler = { [weak self] in
                self?.refreshIfNeeded(force: true)
            }
        }
        refreshIfNeeded(force: true)
    }
    
    func refreshIfNeeded(force: Bool = false) {
        guard let overlay, let mapView else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastRefreshDate) > refreshThrottle else { return }
        lastRefreshDate = now
        
        // Force tile refresh by removing and re-adding the overlay
        mapView.removeOverlay(overlay)
        mapView.addOverlay(overlay, level: .aboveRoads)
        
        resetStaleTimer()
        Task { @MainActor in
            state.update(with: now)
        }
    }
    
    private func resetStaleTimer() {
        staleTimer?.invalidate()
        staleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.state.update(with: self.lastRefreshDate)
            }
        }
    }
}

private final class MapboxTrafficTileOverlay: MKTileOverlay {
    private let accessToken: String
    private let cache = NSCache<NSString, NSData>()
    private let session: URLSession
    
    init(accessToken: String, session: URLSession = .shared) {
        self.accessToken = accessToken
        self.session = session
        super.init(urlTemplate: nil)
        tileSize = CGSize(width: 256, height: 256)
    }
    
    override func loadTile(
        at path: MKTileOverlayPath,
        result: @escaping (Data?, Error?) -> Void
    ) {
        let key = cacheKey(for: path)
        if let cached = cache.object(forKey: key) {
            result(cached as Data, nil)
            return
        }
        
        let url = url(forTilePath: path)
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 10
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let data, (response as? HTTPURLResponse)?.statusCode == 200 {
                self?.cache.setObject(data as NSData, forKey: key)
                result(data, nil)
            } else {
                result(nil, error)
            }
        }.resume()
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let template = "https://api.mapbox.com/styles/v1/mapbox/traffic-day-v2/tiles/256/\(path.z)/\(path.x)/\(path.y)@2x?access_token=\(accessToken)"
        return URL(string: template)!
    }
    
    private func cacheKey(for path: MKTileOverlayPath) -> NSString {
        NSString(string: "\(path.z)-\(path.x)-\(path.y)")
    }
}

