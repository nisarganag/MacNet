import AppKit
import Testing
@testable import MacNetCore

@Suite struct MenuBarLabel {
    /// Idle, both rounding boundaries, a unit change, and a huge rate.
    static let rates: [Double] = [0, 999, 9_960, 999_600, 2.5e9]

    @Test(arguments: UnitStyle.allCases)
    func imageSizeNeverDependsOnTheValues(_ style: UnitStyle) {
        let expected = MenuBarLabelRenderer.size(style: style)
        for up in Self.rates {
            for down in Self.rates {
                let image = MenuBarLabelRenderer.image(
                    upload: SpeedFormatter.compact(bytesPerSecond: up, style: style),
                    download: SpeedFormatter.compact(bytesPerSecond: down, style: style),
                    style: style)
                #expect(image.size == expected)
            }
        }
    }

    /// The fixed width is only honest if every string the formatter can
    /// produce fits its reserved column — otherwise text would be clipped or
    /// overlap. Checked against the formatter's real output, not templates.
    @Test(arguments: UnitStyle.allCases)
    func everyFormattedValueFitsItsColumns(_ style: UnitStyle) {
        let metrics = MenuBarLabelRenderer.metrics(style: style)
        var rate = 1.0
        while rate < 1e13 {
            for factor in [1, 9.96, 99.6, 999.4, 999.6] {
                let speed = SpeedFormatter.compact(bytesPerSecond: rate * factor, style: style)
                #expect(MenuBarLabelRenderer.width(of: speed.number) <= metrics.numberWidth + 0.01, "\(speed.number)")
                #expect(MenuBarLabelRenderer.width(of: speed.unit) <= metrics.unitWidth + 0.01, "\(speed.unit)")
            }
            rate *= 10
        }
    }

    @Test func imageIsATemplateSoTheMenuBarTintsIt() {
        let speed = SpeedFormatter.compact(bytesPerSecond: 3_000, style: .bytes)
        #expect(MenuBarLabelRenderer.image(upload: speed, download: speed, style: .bytes).isTemplate)
    }

    /// The owner's 13" MacBook Air overflowed with the old ~75 pt label.
    @Test func bytesLabelIsCompact() {
        let size = MenuBarLabelRenderer.size(style: .bytes)
        #expect(size.width <= 50)
        #expect(size.height == 22)
    }
}
