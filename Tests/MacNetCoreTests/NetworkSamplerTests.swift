import Foundation
import Testing
@testable import MacNetCore

private func snapshot(at uptime: TimeInterval, received: UInt64, sent: UInt64) -> CounterSnapshot {
    CounterSnapshot(counters: ["en0": InterfaceCounter(received: received, sent: sent)], uptime: uptime)
}

@Suite struct NetworkSampling {
    /// Counters are lifetime totals; the first reading only establishes the
    /// baseline, otherwise launch would show every byte since boot as a spike.
    @Test func firstSnapshotOnlySetsTheBaseline() {
        var sampler = NetworkSampler(historyCapacity: 5)
        let rate = sampler.ingest(snapshot(at: 0, received: 9_000_000, sent: 9_000_000))
        #expect(rate == .zero)
        #expect(sampler.history.samples.isEmpty)
        #expect(sampler.totalReceived == 0)
        #expect(sampler.totalSent == 0)
    }

    @Test func laterSnapshotsProduceRatesHistoryAndTotals() {
        var sampler = NetworkSampler(historyCapacity: 5)
        sampler.ingest(snapshot(at: 0, received: 0, sent: 0))
        sampler.ingest(snapshot(at: 1, received: 1_000, sent: 100))
        let rate = sampler.ingest(snapshot(at: 2, received: 3_000, sent: 300))
        #expect(rate.download == 2_000)
        #expect(rate.upload == 200)
        #expect(sampler.current == rate)
        #expect(sampler.history.samples.count == 2)
        #expect(sampler.totalReceived == 3_000)
        #expect(sampler.totalSent == 300)
    }

    /// A failed counter read (nil) keeps showing the last rate instead of
    /// dropping to zero, and the next good read is diffed against the last
    /// good one, so no traffic goes missing.
    @Test func aFailedReadKeepsTheLastRate() {
        var sampler = NetworkSampler(historyCapacity: 5)
        sampler.ingest(snapshot(at: 0, received: 0, sent: 0))
        let rate = sampler.ingest(snapshot(at: 1, received: 1_000, sent: 100))
        #expect(sampler.ingest(nil) == rate)
        #expect(sampler.current == rate)
        #expect(sampler.history.samples.count == 1)
        let next = sampler.ingest(snapshot(at: 3, received: 3_000, sent: 300))
        #expect(next.download == 1_000)
        #expect(sampler.totalReceived == 3_000)
    }
}
