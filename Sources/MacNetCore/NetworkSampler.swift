/// Turns a stream of counter snapshots into the current rate, a short
/// history for the graphs, and totals since launch.
public struct NetworkSampler: Sendable {
    public private(set) var current: Throughput = .zero
    public private(set) var history: RateHistory
    public private(set) var totalReceived: UInt64 = 0
    public private(set) var totalSent: UInt64 = 0
    private var previous: CounterSnapshot?

    public init(historyCapacity: Int) {
        history = RateHistory(capacity: historyCapacity)
    }

    /// The first snapshot only becomes the baseline — counters are lifetime
    /// totals, so diffing against nothing would report everything since boot.
    /// A failed read (nil) keeps the last rate and the last good baseline, so
    /// the next good read covers the gap instead of losing its traffic.
    @discardableResult
    public mutating func ingest(_ snapshot: CounterSnapshot?) -> Throughput {
        guard let snapshot else { return current }
        defer { previous = snapshot }
        guard let previous else { return .zero }
        current = ThroughputCalculator.between(previous, snapshot)
        history.append(current)
        totalReceived += current.receivedBytes
        totalSent += current.sentBytes
        return current
    }
}
