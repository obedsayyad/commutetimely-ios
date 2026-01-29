//
// NetworkMonitor.swift
// CommuteTimely
//
// Network reachability utility for checking internet connection
//

import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    
    @Published var isConnected = false
    @Published var isCellular = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isCellular = path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }
    
    func checkConnection() -> Bool {
        return monitor.currentPath.status == .satisfied
    }
}
