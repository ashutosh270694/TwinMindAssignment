import Foundation
import Network
import Combine

/// Network reachability monitor using NWPathMonitor
final class Reachability: ObservableObject, ReachabilityProtocol {
    
    // MARK: - Properties
    
    @Published var isReachable = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    
    var reachabilityPublisher: AnyPublisher<Bool, Never> {
        $isReachable.eraseToAnyPublisher()
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ReachabilityMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Connection Types
    
    enum ConnectionType: String, CaseIterable {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
        
        init(from path: NWPath) {
            if path.usesInterfaceType(.wifi) {
                self = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                self = .ethernet
            } else {
                self = .unknown
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Starts monitoring network reachability
    func startMonitoring() {
        monitor.start(queue: queue)
    }
    
    /// Stops monitoring network reachability
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Checks if the network is currently reachable
    /// - Returns: True if network is reachable, false otherwise
    func checkReachability() -> Bool {
        return isReachable
    }
    
    /// Gets the current connection type
    /// - Returns: Current connection type
    func getCurrentConnectionType() -> ConnectionType {
        return connectionType
    }
    
    /// Checks if the current connection is expensive (e.g., cellular)
    /// - Returns: True if connection is expensive, false otherwise
    func isConnectionExpensive() -> Bool {
        return isExpensive
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateReachability(path: path)
            }
        }
        
        // Start monitoring immediately
        startMonitoring()
    }
    
    private func updateReachability(path: NWPath) {
        let wasReachable = isReachable
        let wasExpensive = isExpensive
        let wasConnectionType = connectionType
        
        // Update reachability
        isReachable = path.status == .satisfied
        
        // Update connection type
        connectionType = ConnectionType(from: path)
        
        // Update expensive flag
        isExpensive = path.isExpensive
        
        // Log changes for debugging
        if wasReachable != isReachable {
            print("Reachability: Network \(isReachable ? "became reachable" : "became unreachable")")
        }
        
        if wasConnectionType != connectionType {
            print("Reachability: Connection type changed from \(wasConnectionType.rawValue) to \(connectionType.rawValue)")
        }
        
        if wasExpensive != isExpensive {
            print("Reachability: Connection \(isExpensive ? "became expensive" : "became inexpensive")")
        }
    }
}

// MARK: - Convenience Extensions

extension Reachability {
    
    /// Returns a human-readable description of the current network status
    var statusDescription: String {
        if isReachable {
            return "Connected via \(connectionType.rawValue)"
        } else {
            return "Not connected"
        }
    }
    
    /// Returns true if the network is reachable and not expensive
    var isReachableAndInexpensive: Bool {
        return isReachable && !isExpensive
    }
    
    /// Returns true if the network is reachable via WiFi or Ethernet
    var isReachableViaWiredOrWiFi: Bool {
        return isReachable && (connectionType == .wifi || connectionType == .ethernet)
    }
    
    /// Returns true if the network is reachable via cellular
    var isReachableViaCellular: Bool {
        return isReachable && connectionType == .cellular
    }
}

// MARK: - Publisher Extensions

extension Reachability {
    
    /// Publisher that emits when connection type changes
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        return $connectionType.eraseToAnyPublisher()
    }
    
    /// Publisher that emits when connection expense changes
    var expensePublisher: AnyPublisher<Bool, Never> {
        return $isExpensive.eraseToAnyPublisher()
    }
    
    /// Publisher that emits when any network property changes
    var networkStatusPublisher: AnyPublisher<(isReachable: Bool, connectionType: ConnectionType, isExpensive: Bool), Never> {
        return Publishers.CombineLatest3($isReachable, $connectionType, $isExpensive)
            .map { (isReachable: $0, connectionType: $1, isExpensive: $2) }
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits network status for orchestrator use
    var networkPublisher: AnyPublisher<(isReachable: Bool, connectionType: ConnectionType, isExpensive: Bool), Never> {
        return networkStatusPublisher
    }
}

// MARK: - Testing Support

extension Reachability {
    
    #if DEBUG
    /// Simulates network reachability changes for testing
    /// - Parameters:
    ///   - isReachable: Simulated reachability state
    ///   - connectionType: Simulated connection type
    ///   - isExpensive: Simulated expense state
    func simulateNetworkChange(
        isReachable: Bool,
        connectionType: ConnectionType = .wifi,
        isExpensive: Bool = false
    ) {
        self.isReachable = isReachable
        self.connectionType = connectionType
        self.isExpensive = isExpensive
    }
    #endif
} 