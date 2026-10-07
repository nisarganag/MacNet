import MacNetCore
import SwiftUI

/// The last 60 readings of traffic — a minute at the default 1 s interval,
/// five at 5 s — as one mirrored waveform: upload rises above
/// the centre line and download falls below it — the same arrangement as the
/// menu bar label (↑ on top, ↓ below) and the readouts beside the graph.
struct ThroughputGraph: View {
    let history: RateHistory

    /// The scale never shrinks below 20 KB/s, so an idle link reads as quiet
    /// instead of blowing background chatter up into full-height waves.
    private static let minimumScale: Double = 20_000

    var body: some View {
        Canvas { context, size in
            let mid = (size.height / 2).rounded()
            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: mid))
            axis.addLine(to: CGPoint(x: size.width, y: mid))
            context.stroke(axis, with: .color(.primary.opacity(0.14)), lineWidth: 1)

            let samples = history.samples
            guard samples.count > 1 else { return }
            let scale = max(history.peak, Self.minimumScale)
            let reach = mid - 2
            // Square root rather than linear: a 50 MB/s burst shouldn't
            // flatten every other second into an invisible line.
            func extent(_ rate: Double) -> CGFloat { CGFloat((rate / scale).squareRoot()) * reach }
            let step = size.width / CGFloat(max(history.capacity - 1, 1))
            let startX = size.width - CGFloat(samples.count - 1) * step

            let up = samples.enumerated().map {
                CGPoint(x: startX + CGFloat($0.offset) * step, y: mid - extent($0.element.upload))
            }
            let down = samples.enumerated().map {
                CGPoint(x: startX + CGFloat($0.offset) * step, y: mid + extent($0.element.download))
            }
            Self.drawWave(up, baseline: mid, edge: 0, color: Theme.upload, in: context)
            Self.drawWave(down, baseline: mid, edge: size.height, color: Theme.download, in: context)
        }
        .accessibilityHidden(true)
    }

    private static func drawWave(_ points: [CGPoint], baseline: CGFloat, edge: CGFloat,
                                 color: Color, in context: GraphicsContext) {
        let line = smoothed(points)
        var area = line
        area.addLine(to: CGPoint(x: points[points.count - 1].x, y: baseline))
        area.addLine(to: CGPoint(x: points[0].x, y: baseline))
        area.closeSubpath()
        context.fill(area, with: .linearGradient(
            Gradient(colors: [color.opacity(0.06), color.opacity(0.42)]),
            startPoint: CGPoint(x: 0, y: baseline), endPoint: CGPoint(x: 0, y: edge)))
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    /// Quadratic curves through the midpoints between samples. Unlike
    /// Catmull-Rom this never overshoots, so a wave can't dip across the
    /// centre line into the other direction's half.
    private static func smoothed(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for i in 1 ..< points.count {
            let midpoint = CGPoint(x: (points[i - 1].x + points[i].x) / 2, y: (points[i - 1].y + points[i].y) / 2)
            path.addQuadCurve(to: midpoint, control: points[i - 1])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
