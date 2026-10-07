import Foundation
import Testing
@testable import MacNetCore

private func snapshot(at uptime: TimeInterval, _ counters: [String: (received: UInt64, sent: UInt64)]) -> CounterSnapshot {
    CounterSnapshot(counters: counters.mapValues { InterfaceCounter(received: $0.received, sent: $0.sent) },
                    uptime: uptime)
}

@Suite struct ThroughputMaths {
    @Test func ratesArePerSecond() {
        let t = ThroughputCalculator.between(snapshot(at: 10, ["en0": (5_000, 2_000)]),
                                             snapshot(at: 11, ["en0": (6_000, 2_500)]))
        #expect(t.download == 1_000)
        #expect(t.upload == 500)
        #expect(t.receivedBytes == 1_000)
        #expect(t.sentBytes == 500)
    }

    @Test func longerIntervalLowersTheRate() {
        let t = ThroughputCalculator.between(snapshot(at: 10, ["en0": (5_000, 2_000)]),
                                             snapshot(at: 12, ["en0": (6_000, 2_500)]))
        #expect(t.download == 500)
        #expect(t.upload == 250)
        #expect(t.receivedBytes == 1_000)
    }

    @Test func interfacesAreSummed() {
        let t = ThroughputCalculator.between(snapshot(at: 0, ["en0": (0, 0), "en5": (0, 0)]),
                                             snapshot(at: 1, ["en0": (300, 30), "en5": (700, 70)]))
        #expect(t.download == 1_000)
        #expect(t.upload == 100)
    }

    /// Interfaces reset their counters when they bounce; that must read as
    /// "nothing new on this one", never as a negative or wrapped-around rate.
    @Test func counterResetCountsAsZero() {
        let t = ThroughputCalculator.between(snapshot(at: 0, ["en0": (5_000, 5_000), "en5": (0, 0)]),
                                             snapshot(at: 1, ["en0": (100, 100), "en5": (1_000, 10)]))
        #expect(t.download == 1_000)
        #expect(t.upload == 10)
    }

    @Test func unpluggedInterfaceIsIgnored() {
        let t = ThroughputCalculator.between(snapshot(at: 0, ["en0": (0, 0), "en7": (9_000, 9_000)]),
                                             snapshot(at: 1, ["en0": (400, 40)]))
        #expect(t.download == 400)
        #expect(t.upload == 40)
    }

    /// A freshly plugged-in adapter arrives with lifetime totals; counting
    /// them would show one enormous spike.
    @Test func newInterfaceWaitsForABaseline() {
        let t = ThroughputCalculator.between(snapshot(at: 0, ["en0": (0, 0)]),
                                             snapshot(at: 1, ["en0": (400, 40), "en7": (9_000_000, 9_000_000)]))
        #expect(t.download == 400)
        #expect(t.upload == 40)
    }

    @Test(arguments: [0.0, -1.0])
    func nonPositiveElapsedIsZero(_ elapsed: Double) {
        let t = ThroughputCalculator.between(snapshot(at: 10, ["en0": (0, 0)]),
                                             snapshot(at: 10 + elapsed, ["en0": (1_000, 1_000)]))
        #expect(t == .zero)
    }
}

@Suite struct InterfaceFiltering {
    @Test(arguments: ["en0", "en5", "en12", "pdp_ip0"])
    func countsPhysicalInterfaces(_ name: String) {
        #expect(InterfaceFilter.counts(name))
    }

    /// Tunnels carry traffic that is also counted on the physical interface
    /// beneath them; loopback and peer-to-peer links never touch the internet.
    @Test(arguments: ["lo0", "utun3", "awdl0", "llw0", "bridge0", "ap1", "anpi0", "gif0", "en", "enc0"])
    func skipsVirtualInterfaces(_ name: String) {
        #expect(!InterfaceFilter.counts(name))
    }
}
