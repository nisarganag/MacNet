import Foundation

/// How speeds are expressed: bytes (`K/s`, the macOS convention) or bits
/// (`Kb/s`, the networking one).
public enum UnitStyle: String, CaseIterable, Codable, Sendable {
    case bytes, bits
}

/// A formatted speed split into number and unit, so callers can lay the two
/// out independently — right-aligned digits next to a fixed unit column.
public struct CompactSpeed: Equatable, Sendable {
    public let number: String
    public let unit: String

    public init(number: String, unit: String) {
        self.number = number
        self.unit = unit
    }
}

/// Every unit ladder steps by 1000, the convention macOS itself has used for
/// sizes and rates since 10.6.
public enum SpeedFormatter {
    /// The menu bar's unit ladders. Exposed so the label can reserve the width
    /// of the widest unit up front instead of jumping when the unit changes.
    public static let compactUnits: [UnitStyle: [String]] = [
        .bytes: ["K/s", "M/s", "G/s", "T/s"],
        .bits: ["Kb/s", "Mb/s", "Gb/s", "Tb/s"],
    ]

    private static let detailedUnits: [UnitStyle: [String]] = [
        .bytes: ["KB/s", "MB/s", "GB/s", "TB/s"],
        .bits: ["Kb/s", "Mb/s", "Gb/s", "Tb/s"],
    ]

    /// One decimal below 10, whole numbers up to 999: never more than three
    /// digits, which is what lets the menu bar label have a fixed width.
    private static let compactSteps: [Step] = [Step(decimals: 1, below: 10), Step(decimals: 0, below: 1000)]

    /// Three significant figures, for places with room to spare.
    private static let detailedSteps: [Step] = [
        Step(decimals: 2, below: 10), Step(decimals: 1, below: 100), Step(decimals: 0, below: 1000),
    ]

    /// The menu bar form. Kilo is the smallest unit, so a quiet link reads
    /// `0.3 K/s` rather than switching to a separate (and wider) bytes unit.
    public static func compact(bytesPerSecond: Double, style: UnitStyle) -> CompactSpeed {
        scaled(rate(bytesPerSecond, style) / 1000, units: compactUnits[style] ?? [], steps: compactSteps)
    }

    /// The panel form: three significant figures with full unit names.
    public static func detailed(bytesPerSecond: Double, style: UnitStyle) -> CompactSpeed {
        scaled(rate(bytesPerSecond, style) / 1000, units: detailedUnits[style] ?? [], steps: detailedSteps)
    }

    /// Speed test results, in decimal megabits as ISPs and other speed tests
    /// report them (not the 2^20 "Mbps" in `networkQuality`'s own summary).
    public static func megabits(_ bitsPerSecond: Double) -> CompactSpeed {
        scaled(sanitized(bitsPerSecond) / 1_000_000, units: ["Mbps", "Gbps", "Tbps"], steps: detailedSteps)
    }

    /// Data totals such as "1.2 GB".
    public static func bytes(_ count: UInt64) -> String {
        guard count > 0 else { return "0 KB" }
        let size = scaled(Double(count) / 1000, units: ["KB", "MB", "GB", "TB"], steps: compactSteps)
        return "\(size.number) \(size.unit)"
    }

    /// A unit as words, for VoiceOver — which reads "KB/s" letter by letter.
    public static func spokenUnit(_ unit: String) -> String {
        let prefixes: [Character: String] = ["K": "kilo", "M": "mega", "G": "giga", "T": "tera"]
        guard let first = unit.first, let prefix = prefixes[first] else { return unit }
        // Bytes are a capital B or a bare "K/s"; bits a lowercase b or "bps".
        let rest = unit.dropFirst()
        let bits = rest.hasPrefix("b")
        return "\(prefix)\(bits ? "bits" : "bytes") per second"
    }

    private struct Step {
        let decimals: Int
        let below: Double
    }

    private static func rate(_ bytesPerSecond: Double, _ style: UnitStyle) -> Double {
        sanitized(bytesPerSecond) * (style == .bits ? 8 : 1)
    }

    /// A counter glitch must read as idle, not as a crash or a garbage label.
    private static func sanitized(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }

    /// Picks the first unit and precision whose ROUNDED value still fits.
    /// Deciding on the rounded value rather than the raw one is what keeps
    /// 9.96 from printing as "10.0" (four characters) and 999.6 from printing
    /// as "1000" — both would overflow the reserved width.
    private static func scaled(_ value: Double, units: [String], steps: [Step]) -> CompactSpeed {
        var value = value
        for unit in units {
            for step in steps {
                let scale = pow(10, Double(step.decimals))
                let rounded = (value * scale).rounded() / scale
                if rounded < step.below {
                    return CompactSpeed(number: String(format: "%.\(step.decimals)f", rounded), unit: unit)
                }
            }
            value /= 1000
        }
        // Past the largest unit (petabytes per second): pin rather than overflow.
        return CompactSpeed(number: "999", unit: units.last ?? "")
    }
}
