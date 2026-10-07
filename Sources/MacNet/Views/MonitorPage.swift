import MacNetCore
import SwiftUI

struct MonitorPage: View {
    let monitor: NetworkMonitor
    let connection: ConnectionMonitor
    let tester: SpeedTester
    let preferences: Preferences
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            liveTraffic
            totals
            SpeedTestCard(tester: tester, monitor: monitor)
            Spacer(minLength: 0)
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("MacNet")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Label(connection.kind.label, systemImage: connection.kind.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .accessibilityLabel("Connection: \(connection.kind.label)")
                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .help("Settings")
                    .accessibilityLabel("Settings")
                }
            }
        }
    }

    /// Readouts stacked like the menu bar label — upload over download — each
    /// beside its own half of the mirrored graph.
    private var liveTraffic: some View {
        let style = preferences.unitStyle
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                SpeedReadout(title: "Upload", symbol: "arrow.up", color: Theme.upload,
                             speed: SpeedFormatter.detailed(bytesPerSecond: monitor.current.upload, style: style))
                SpeedReadout(title: "Download", symbol: "arrow.down", color: Theme.download,
                             speed: SpeedFormatter.detailed(bytesPerSecond: monitor.current.download, style: style))
            }
            .frame(width: 112, alignment: .leading)
            ThroughputGraph(history: monitor.history)
        }
        // As tall as the readouts and no taller: the graph takes their height
        // rather than competing with the page's spacer for spare room.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var totals: some View {
        HStack {
            Text("Since launch")
            Spacer()
            Text("\(SpeedFormatter.bytes(monitor.totalReceived)) down, \(SpeedFormatter.bytes(monitor.totalSent)) up")
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private var footer: some View {
        HStack {
            Text(AppInfo.versionDescription)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit MacNet", action: quit)
                .buttonStyle(.glass)
                .controlSize(.small)
        }
    }
}

struct SpeedReadout: View {
    let title: String
    let symbol: String
    let color: Color
    let speed: CompactSpeed

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(speed.number)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(speed.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(speed.number) \(SpeedFormatter.spokenUnit(speed.unit))")
    }
}
