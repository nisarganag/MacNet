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
    @discardableResult
    public mutating func ingest(_ snapshot: CounterSnapshot) -> Throughput {
        defer { previous = snapshot }
        guard let previous else { return .zero }
        current = ThroughputCalculator.between(previous, snapshot)
        history.append(current)
        totalReceived += current.receivedBytes
        totalSent += current.sentBytes
        return current
    }
}
