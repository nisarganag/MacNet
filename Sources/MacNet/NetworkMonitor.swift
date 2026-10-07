import Foundation
import MacNetCore
import Observation

/// Samples the interface counters on a timer and publishes the results.
@MainActor @Observable
final class NetworkMonitor {
    /// 60 samples: a minute of history at the default 1 s interval.
    private(set) var sampler = NetworkSampler(historyCapacity: 60)
    @ObservationIgnored private(set) var interval: TimeInterval
    /// Called after every sample, for the menu bar label — which must keep
    /// updating whether or not anything in SwiftUI is observing.
    @ObservationIgnored var onSample: ((Throughput) -> Void)?
    @ObservationIgnored private var timer: DispatchSourceTimer?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    var current: Throughput { sampler.current }
    var history: RateHistory { sampler.history }
    var totalReceived: UInt64 { sampler.totalReceived }
    var totalSent: UInt64 { sampler.totalSent }

    func start() {
        sample()
        schedule()
    }

    func setInterval(_ newValue: TimeInterval) {
        guard newValue != interval else { return }
        interval = newValue
        if timer != nil { schedule() }
    }

    private func schedule() {
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // 10% leeway lets macOS coalesce this wake-up with other timers.
        timer.schedule(deadline: .now() + interval, repeating: interval,
                       leeway: .milliseconds(Int(interval * 100)))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.resume()
        self.timer = timer
    }

    private func sample() {
        let rate = sampler.ingest(InterfaceCounters.snapshot())
        onSample?(rate)
    }
}
