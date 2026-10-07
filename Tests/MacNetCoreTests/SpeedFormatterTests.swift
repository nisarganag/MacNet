import Testing
@testable import MacNetCore

struct SpeedCase: Sendable, CustomTestStringConvertible {
    let input: Double
    let number: String
    let unit: String
    var testDescription: String { "\(input) → \(number) \(unit)" }
}

@Suite struct CompactSpeedFormatting {
    @Test(arguments: [
        SpeedCase(input: 0, number: "0.0", unit: "K/s"),
        SpeedCase(input: 300, number: "0.3", unit: "K/s"),
        SpeedCase(input: 3_000, number: "3.0", unit: "K/s"),
        SpeedCase(input: 9_940, number: "9.9", unit: "K/s"),
        SpeedCase(input: 9_960, number: "10", unit: "K/s"),
        SpeedCase(input: 49_950, number: "50", unit: "K/s"),
        SpeedCase(input: 512_000, number: "512", unit: "K/s"),
        SpeedCase(input: 999_400, number: "999", unit: "K/s"),
        SpeedCase(input: 999_600, number: "1.0", unit: "M/s"),
        SpeedCase(input: 12_500_000, number: "13", unit: "M/s"),
        SpeedCase(input: 2.5e9, number: "2.5", unit: "G/s"),
    ])
    func bytes(_ c: SpeedCase) {
        #expect(SpeedFormatter.compact(bytesPerSecond: c.input, style: .bytes)
                == CompactSpeed(number: c.number, unit: c.unit))
    }

    @Test(arguments: [
        SpeedCase(input: 1_000, number: "8.0", unit: "Kb/s"),
        SpeedCase(input: 125_000, number: "1.0", unit: "Mb/s"),
    ])
    func bits(_ c: SpeedCase) {
        #expect(SpeedFormatter.compact(bytesPerSecond: c.input, style: .bits)
                == CompactSpeed(number: c.number, unit: c.unit))
    }

    @Test(arguments: [-5.0, .nan, .infinity, -.infinity])
    func invalidInputReadsAsZero(_ value: Double) {
        #expect(SpeedFormatter.compact(bytesPerSecond: value, style: .bytes)
                == CompactSpeed(number: "0.0", unit: "K/s"))
    }

    /// The label's width is reserved for at most three digits, so no input may
    /// ever produce a fourth — sweep every decade and both sides of each
    /// rounding boundary rather than trusting the hand-picked cases above.
    @Test(arguments: UnitStyle.allCases)
    func neverMoreThanThreeDigits(_ style: UnitStyle) {
        var decade = 1.0
        while decade < 1e13 {
            for factor in [1, 0.9995, 0.995, 9.95, 9.96, 99.5, 999.4, 999.6] {
                let value = decade * factor
                let speed = SpeedFormatter.compact(bytesPerSecond: value, style: style)
                #expect(speed.number.filter(\.isNumber).count <= 3, "\(value) → \(speed.number)")
                #expect(SpeedFormatter.compactUnits[style]?.contains(speed.unit) == true)
            }
            decade *= 10
        }
    }
}

@Suite struct DetailedSpeedFormatting {
    @Test(arguments: [
        SpeedCase(input: 49_940, number: "49.9", unit: "KB/s"),
        SpeedCase(input: 3_000, number: "3.00", unit: "KB/s"),
        SpeedCase(input: 512_000, number: "512", unit: "KB/s"),
        SpeedCase(input: 999_700, number: "1.00", unit: "MB/s"),
    ])
    func bytes(_ c: SpeedCase) {
        #expect(SpeedFormatter.detailed(bytesPerSecond: c.input, style: .bytes)
                == CompactSpeed(number: c.number, unit: c.unit))
    }

    @Test func bitsUseLowercaseB() {
        #expect(SpeedFormatter.detailed(bytesPerSecond: 125_000, style: .bits)
                == CompactSpeed(number: "1.00", unit: "Mb/s"))
    }
}

@Suite struct MegabitFormatting {
    @Test(arguments: [
        SpeedCase(input: 62_774_924, number: "62.8", unit: "Mbps"),
        SpeedCase(input: 1_250_000_000, number: "1.25", unit: "Gbps"),
        SpeedCase(input: 950_000, number: "0.95", unit: "Mbps"),
    ])
    func megabits(_ c: SpeedCase) {
        #expect(SpeedFormatter.megabits(c.input) == CompactSpeed(number: c.number, unit: c.unit))
    }
}

@Suite struct ByteTotalFormatting {
    @Test(arguments: [
        (UInt64(0), "0 KB"),
        (UInt64(1_234_567), "1.2 MB"),
        (UInt64(5_000_000_000), "5.0 GB"),
        (UInt64(45_000_000), "45 MB"),
    ])
    func totals(_ count: UInt64, _ expected: String) {
        #expect(SpeedFormatter.bytes(count) == expected)
    }
}

@Suite struct SpokenUnits {
    /// VoiceOver reads "KB/s" letter by letter; accessibility labels need words.
    @Test(arguments: ["K/s", "M/s", "KB/s", "MB/s", "GB/s", "Kb/s", "Mb/s", "Gb/s", "Mbps", "Gbps"])
    func spellsOutEveryUnit(_ unit: String) {
        let spoken = SpeedFormatter.spokenUnit(unit)
        #expect(spoken.hasSuffix("per second"), "\(unit) → \(spoken)")
        #expect(!spoken.contains("/"))
    }

    @Test func distinguishesBitsFromBytes() {
        #expect(SpeedFormatter.spokenUnit("Mb/s") == "megabits per second")
        #expect(SpeedFormatter.spokenUnit("MB/s") == "megabytes per second")
    }
}
