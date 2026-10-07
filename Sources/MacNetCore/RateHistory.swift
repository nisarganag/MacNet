/// The most recent throughput samples, oldest first, for the panel's graphs.
public struct RateHistory: Sendable {
    public let capacity: Int
    public private(set) var samples: [Throughput] = []

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    public mutating func append(_ sample: Throughput) {
        samples.append(sample)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    /// The highest rate in either direction still in the window — the shared
    /// scale that keeps the download and upload graphs comparable.
    public var peak: Double {
        samples.reduce(0) { max($0, $1.download, $1.upload) }
    }
}
