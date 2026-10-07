import Foundation
import MacNetCore
import Observation

enum GlassStyle: String, CaseIterable, Sendable {
    /// Frosted: the most legible over busy wallpapers.
    case regular
    /// Barely-there glass for people who want the desktop to show through.
    case clear
}

/// User settings, written to UserDefaults the moment they change.
@MainActor @Observable
final class Preferences {
    static let intervals: [TimeInterval] = [1, 2, 5]

    var updateInterval: TimeInterval {
        didSet { defaults.set(updateInterval, forKey: Key.interval) }
    }
    var unitStyle: UnitStyle {
        didSet { defaults.set(unitStyle.rawValue, forKey: Key.units) }
    }
    var glassStyle: GlassStyle {
        didSet { defaults.set(glassStyle.rawValue, forKey: Key.glass) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let interval = defaults.double(forKey: Key.interval)
        updateInterval = Self.intervals.contains(interval) ? interval : 1
        unitStyle = UnitStyle(rawValue: defaults.string(forKey: Key.units) ?? "") ?? .bytes
        glassStyle = GlassStyle(rawValue: defaults.string(forKey: Key.glass) ?? "") ?? .regular
    }

    private enum Key {
        static let interval = "updateInterval"
        static let units = "unitStyle"
        static let glass = "glassStyle"
    }
}
