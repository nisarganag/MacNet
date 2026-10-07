import MacNetCore
import SwiftUI

/// Runs a speed test and shows its progress, its result, or what went wrong.
struct SpeedTestCard: View {
    let tester: SpeedTester
    let monitor: NetworkMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Internet speed")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                status
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            content
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            action
        }
        .glassCard()
        .animation(.smooth(duration: 0.35), value: tester.state)
        .animation(.smooth(duration: 0.35), value: tester.lastResult)
    }

    @ViewBuilder private var status: some View {
        switch tester.state {
        case let .running(started):
            Text(started, style: .timer)
                .monospacedDigit()
        case .idle, .failed:
            if let result = tester.lastResult {
                Text(result.date, format: .relative(presentation: .named))
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch tester.state {
        case .running:
            // The tool reports nothing until it finishes, so the live figures
            // are MacNet's own reading of the traffic the test is generating.
            VStack(alignment: .leading, spacing: 10) {
                speeds(download: monitor.current.download * 8, upload: monitor.current.upload * 8)
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Theme.download)
                Text("About 30 seconds, using Apple's servers.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.multicolor)
        case .idle:
            if let result = tester.lastResult {
                VStack(alignment: .leading, spacing: 10) {
                    speeds(download: result.downloadBitsPerSecond, upload: result.uploadBitsPerSecond)
                    HStack(spacing: 24) {
                        Metric(title: "Latency", value: result.idleLatencyMilliseconds
                            .map { "\(Int($0.rounded())) ms" } ?? "Not measured")
                        Metric(title: "Responsiveness", value: responsiveness(result))
                    }
                }
            } else {
                Text("Measure your download and upload speed with Apple's test servers.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var action: some View {
        switch tester.state {
        case .running:
            Button { tester.cancel() } label: { Text("Cancel").frame(maxWidth: .infinity) }
                .buttonStyle(.glass)
                .controlSize(.large)
        case .failed:
            Button { tester.start() } label: { Text("Try Again").frame(maxWidth: .infinity) }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        case .idle:
            Button { tester.start() } label: {
                Text(tester.lastResult == nil ? "Test Internet Speed" : "Test Again").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    private func speeds(download: Double, upload: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            ResultValue(title: "Download", symbol: "arrow.down", color: Theme.download, bitsPerSecond: download)
            Spacer()
            ResultValue(title: "Upload", symbol: "arrow.up", color: Theme.upload, bitsPerSecond: upload)
            Spacer()
        }
    }

    /// Apple's own verdict when the tool gave one, with the measurement it
    /// rests on; just the measurement otherwise.
    private func responsiveness(_ result: SpeedTestResult) -> String {
        let rpm = result.responsivenessRPM.map { "\(Int($0.rounded())) RPM" }
        switch (result.responsivenessRating, rpm) {
        case let (rating?, rpm?): return "\(rating) (\(rpm))"
        case let (rating?, nil): return rating
        case let (nil, rpm?): return rpm
        case (nil, nil): return "Not measured"
        }
    }
}

private struct ResultValue: View {
    let title: String
    let symbol: String
    let color: Color
    let bitsPerSecond: Double

    var body: some View {
        let speed = SpeedFormatter.megabits(bitsPerSecond)
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(speed.number)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(speed.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(speed.number) \(SpeedFormatter.spokenUnit(speed.unit))")
    }
}

private struct Metric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
