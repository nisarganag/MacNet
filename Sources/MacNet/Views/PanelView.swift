import MacNetCore
import Observation
import SwiftUI

/// Which page the open panel shows. An object rather than view state so the
/// panel's Escape handling (in AppKit) can step back out of Settings.
@MainActor @Observable
final class PanelNavigation {
    var page: PanelPage

    init(page: PanelPage) {
        self.page = page
    }

    func show(_ page: PanelPage) {
        withAnimation(.smooth(duration: 0.32)) { self.page = page }
    }
}

/// The panel's root: the monitor page, with settings sliding in over it.
struct PanelView: View {
    let monitor: NetworkMonitor
    let connection: ConnectionMonitor
    let tester: SpeedTester
    let preferences: Preferences
    let loginItem: LoginItem
    let navigation: PanelNavigation
    let quit: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            switch navigation.page {
            case .monitor:
                MonitorPage(monitor: monitor, connection: connection, tester: tester,
                            preferences: preferences, openSettings: { navigation.show(.settings) }, quit: quit)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .settings:
                SettingsPage(preferences: preferences, loginItem: loginItem, back: { navigation.show(.monitor) })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(width: Theme.panelSize.width, height: Theme.panelSize.height, alignment: .top)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .panelSurface(preferences.glassStyle, dark: colorScheme == .dark)
    }
}
