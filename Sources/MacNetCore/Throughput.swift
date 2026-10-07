import Foundation

/// Lifetime byte counters for one network interface.
public struct InterfaceCounter: Equatable, Sendable {
    public var received: UInt64
    public var sent: UInt64

    public init(received: UInt64, sent: UInt64) {
        self.received = received
        self.sent = sent
    }
}

/// Every counted interface's counters at one instant. `uptime` is the time
/// the Mac has been awake since boot: monotonic, so clock changes can't skew
/// a rate, and frozen during sleep, so the first rate after waking averages
/// over awake time and stays bounded rather than reading as a spike.
public struct CounterSnapshot: Equatable, Sendable {
    public var counters: [String: InterfaceCounter]
    public var uptime: TimeInterval

    public init(counters: [String: InterfaceCounter], uptime: TimeInterval) {
        self.counters = counters
        self.uptime = uptime
    }
}

/// Transfer rates in bytes per second, plus the bytes that produced them.
public struct Throughput: Equatable, Sendable {
    public var download: Double
    public var upload: Double
    public var receivedBytes: UInt64
    public var sentBytes: UInt64

    public init(download: Double, upload: Double, receivedBytes: UInt64, sentBytes: UInt64) {
        self.download = download
        self.upload = upload
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }

    public static let zero = Throughput(download: 0, upload: 0, receivedBytes: 0, sentBytes: 0)
}

public enum ThroughputCalculator {
    /// Rates between two snapshots, computed per interface and then summed.
    ///
    /// Only interfaces present in BOTH snapshots contribute: one that vanished
    /// has nothing to compare, and one that just appeared would otherwise add
    /// its whole lifetime total as a single spike. A counter that went
    /// backwards (the interface bounced and reset) contributes zero.
    public static func between(_ old: CounterSnapshot, _ new: CounterSnapshot) -> Throughput {
        let elapsed = new.uptime - old.uptime
        guard elapsed > 0 else { return .zero }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        for (name, now) in new.counters {
            guard let before = old.counters[name] else { continue }
            received += now.received >= before.received ? now.received - before.received : 0
            sent += now.sent >= before.sent ? now.sent - before.sent : 0
        }
        return Throughput(download: Double(received) / elapsed, upload: Double(sent) / elapsed,
                          receivedBytes: received, sentBytes: sent)
    }
}

public enum InterfaceFilter {
    /// Physical links only: Ethernet/Wi-Fi (`en*`) and cellular (`pdp_ip*`).
    ///
    /// VPN tunnels (`utun*`, `ipsec*`) are excluded because their traffic is
    /// also counted, encrypted, on the physical interface beneath them —
    /// including both would double it. Loopback, AirDrop (`awdl`, `llw`),
    /// bridges and the rest never carry internet traffic of their own.
    public static func counts(_ name: String) -> Bool {
        for prefix in ["en", "pdp_ip"] where name.hasPrefix(prefix) {
            let unit = name.dropFirst(prefix.count)
            return !unit.isEmpty && unit.allSatisfy(\.isASCIIDigit)
        }
        return false
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
