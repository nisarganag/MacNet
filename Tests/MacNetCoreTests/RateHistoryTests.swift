import Testing
@testable import MacNetCore

private func rate(down: Double, up: Double = 0) -> Throughput {
    Throughput(download: down, upload: up, receivedBytes: 0, sentBytes: 0)
}

@Suite struct RateHistoryBuffer {
    @Test func keepsOnlyTheNewestSamples() {
        var history = RateHistory(capacity: 3)
        for i in 1...5 { history.append(rate(down: Double(i))) }
        #expect(history.samples.map(\.download) == [3, 4, 5])
    }

    @Test func peakIsTheLargestRateInEitherDirection() {
        var history = RateHistory(capacity: 4)
        history.append(rate(down: 10, up: 50))
        history.append(rate(down: 30, up: 5))
        #expect(history.peak == 50)
    }

    @Test func peakForgetsSamplesThatFellOut() {
        var history = RateHistory(capacity: 2)
        history.append(rate(down: 100))
        history.append(rate(down: 1))
        history.append(rate(down: 2))
        #expect(history.peak == 2)
    }

    @Test func emptyHistoryHasZeroPeak() {
        let history = RateHistory(capacity: 3)
        #expect(history.samples.isEmpty)
        #expect(history.peak == 0)
    }
}
