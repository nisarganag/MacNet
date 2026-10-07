import Foundation
import MacNetCore
import Observation
import os

private let log = Logger(subsystem: "com.nisarganag.macnet", category: "speedtest")

/// Runs speed tests independently of the panel, so closing the panel mid-test
/// doesn't lose the result, and remembers the last result across launches.
@MainActor @Observable
final class SpeedTester {
    enum State: Equatable {
        case idle
        case running(started: Date)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastResult: SpeedTestResult? {
        didSet { save() }
    }
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let runner: NetworkQualityRunner
    @ObservationIgnored private let defaults: UserDefaults

    init(runner: NetworkQualityRunner = NetworkQualityRunner(), defaults: UserDefaults = .standard) {
        self.runner = runner
        self.defaults = defaults
        lastResult = defaults.data(forKey: Self.resultKey)
            .flatMap { try? JSONDecoder().decode(SpeedTestResult.self, from: $0) }
    }

    var isRunning: Bool {
        if case .running = state { true } else { false }
    }

    func start() {
        guard !isRunning else { return }
        state = .running(started: Date())
        log.notice("speed test started")
        task = Task { [runner] in
            do {
                let result = try await runner.run()
                log.notice("speed test finished: \(Int(result.downloadBitsPerSecond)) down, \(Int(result.uploadBitsPerSecond)) up bit/s")
                lastResult = result
                state = .idle
            } catch is CancellationError {
                log.notice("speed test cancelled")
                state = .idle
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                log.error("speed test failed: \(message, privacy: .public)")
                state = .failed(message)
            }
            task = nil
        }
    }

    /// Terminates the `networkQuality` process synchronously (through the
    /// runner's cancellation handler), so this is safe to call while quitting.
    func cancel() {
        task?.cancel()
    }

    func dismissFailure() {
        if case .failed = state { state = .idle }
    }

    private static let resultKey = "lastSpeedTest"

    private func save() {
        defaults.set(lastResult.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.resultKey)
    }
}
