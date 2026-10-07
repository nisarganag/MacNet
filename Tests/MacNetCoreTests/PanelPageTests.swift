import Testing
@testable import MacNetCore

@Suite struct PanelEscape {
    /// Escape steps back out of Settings first, like leaving a submenu…
    @Test func escapeFromSettingsGoesBackToTheMonitor() {
        #expect(PanelPage.settings.afterEscape == .monitor)
    }

    /// …and only closes the panel from the top level.
    @Test func escapeFromTheMonitorClosesThePanel() {
        #expect(PanelPage.monitor.afterEscape == nil)
    }
}
