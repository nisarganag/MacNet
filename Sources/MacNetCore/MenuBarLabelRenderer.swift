import AppKit

/// Draws the two-line menu bar label — upload on top, download below — as one
/// fixed-size template image.
///
/// An image rather than the status button's title: a title is a single line
/// and re-lays-out whenever its text changes, nudging every item to its left.
/// A constant-size image keeps the rest of the menu bar perfectly still.
/// Template, so the system tints it for light, dark and wallpaper-tinted
/// bars; there is deliberately no background — the menu bar shows through.
public enum MenuBarLabelRenderer {
    /// `NSStatusBar.system.thickness`. The bar centres the image vertically,
    /// including on notched displays where the bar itself is taller.
    static let height: CGFloat = 22
    // Computed: NSFont isn't Sendable, and AppKit caches system fonts anyway.
    static var font: NSFont { .monospacedDigitSystemFont(ofSize: 9, weight: .medium) }
    static var arrowFont: NSFont { .systemFont(ofSize: 8.5, weight: .bold) }
    /// Both narrower than a space (2.6 pt at this size): the old label's
    /// generous spacing is what pushed the owner's menu bar into overflow.
    static let arrowGap: CGFloat = 2
    static let unitGap: CGFloat = 1.5
    /// Clear space between the top line's baseline and the bottom line's caps.
    static let lineGap: CGFloat = 3

    struct Metrics: Equatable, Sendable {
        let arrowWidth: CGFloat
        let numberWidth: CGFloat
        let unitWidth: CGFloat

        var width: CGFloat {
            (arrowWidth + MenuBarLabelRenderer.arrowGap + numberWidth
                + MenuBarLabelRenderer.unitGap + unitWidth).rounded(.up)
        }
    }

    static func metrics(style: UnitStyle) -> Metrics {
        Metrics(
            arrowWidth: max(width(of: "↑", font: arrowFont), width(of: "↓", font: arrowFont)),
            // Digits are monospaced in this font and the compact formatter
            // never emits more than three, so "888" is the widest number.
            numberWidth: width(of: "888"),
            unitWidth: (SpeedFormatter.compactUnits[style] ?? []).map { width(of: $0) }.max() ?? 0)
    }

    public static func size(style: UnitStyle) -> NSSize {
        NSSize(width: metrics(style: style).width, height: height)
    }

    public static func image(upload: CompactSpeed, download: CompactSpeed, style: UnitStyle) -> NSImage {
        let metrics = metrics(style: style)
        let capHeight = font.capHeight
        let bottomBaseline = ((height - (capHeight * 2 + lineGap)) / 2 * 2).rounded() / 2
        let topBaseline = bottomBaseline + capHeight + lineGap

        let image = NSImage(size: NSSize(width: metrics.width, height: height), flipped: false) { _ in
            drawLine(arrow: "↑", speed: upload, baseline: topBaseline, metrics: metrics)
            drawLine(arrow: "↓", speed: download, baseline: bottomBaseline, metrics: metrics)
            return true
        }
        image.isTemplate = true
        return image
    }

    static func width(of text: String, font: NSFont = font) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// Arrow at the left edge, digits right-aligned against the unit column so
    /// the decimal places of both lines line up as the values change.
    private static func drawLine(arrow: String, speed: CompactSpeed, baseline: CGFloat, metrics: Metrics) {
        draw(arrow, font: arrowFont, x: 0, baseline: baseline)
        let numberRight = metrics.arrowWidth + arrowGap + metrics.numberWidth
        draw(speed.number, font: font, x: numberRight - width(of: speed.number), baseline: baseline)
        draw(speed.unit, font: font, x: numberRight + unitGap, baseline: baseline)
    }

    /// `draw(at:)` takes the bottom-left of the line box, which sits one
    /// descender below the baseline.
    private static func draw(_ text: String, font: NSFont, x: CGFloat, baseline: CGFloat) {
        (text as NSString).draw(at: NSPoint(x: x, y: baseline + font.descender),
                                withAttributes: [.font: font, .foregroundColor: NSColor.black])
    }
}
