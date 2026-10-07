import Network
import Observation

enum ConnectionKind: Sendable {
    case wifi, ethernet, cellular, other, offline

    init(_ path: NWPath) {
        guard path.status == .satisfied else {
            self = .offline
            return
        }
        if path.usesInterfaceType(.wifi) {
            self = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            self = .ethernet
        } else if path.usesInterfaceType(.cellular) {
            self = .cellular
        } else {
            self = .other
        }
    }

    var label: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .ethernet: "Ethernet"
        case .cellular: "Cellular"
        case .other: "Connected"
        case .offline: "Offline"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .wifi: "wifi"
        case .ethernet: "cable.connector.horizontal"
        case .cellular: "antenna.radiowaves.left.and.right"
        case .other: "network"
        case .offline: "wifi.slash"
        }
    }
}

/// Which kind of link the system is routing traffic over right now.
@MainActor @Observable
final class ConnectionMonitor {
    private(set) var kind: ConnectionKind = .other
    @ObservationIgnored private let monitor = NWPathMonitor()

    func start() {
        // Path changes are rare, so delivering them on the main queue costs
        // nothing and keeps all state on the main actor.
        monitor.pathUpdateHandler = { [weak self] path in
            MainActor.assumeIsolated { self?.kind = ConnectionKind(path) }
        }
        monitor.start(queue: .main)
    }
}
