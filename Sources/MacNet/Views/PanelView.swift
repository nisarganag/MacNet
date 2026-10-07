import SwiftUI

enum PanelPage {
    case monitor, settings
}

/// The panel's root: the monitor page, with settings sliding in over it.
struct PanelView: View {
    let monitor: NetworkMonitor
    let connection: ConnectionMonitor
    let tester: SpeedTester
    let preferences: Preferences
    let loginItem: LoginItem
    let quit: () -> Void
    @State private var page: PanelPage
    @Environment(\.colorScheme) private var colorScheme

    init(monitor: NetworkMonitor, connection: ConnectionMonitor, tester: SpeedTester,
         preferences: Preferences, loginItem: LoginItem, page: PanelPage, quit: @escaping () -> Void) {
        self.monitor = monitor
        self.connection = connection
        self.tester = tester
        self.preferences = preferences
        self.loginItem = loginItem
        self.quit = quit
        _page = State(initialValue: page)
    }

    var body: some View {
        ZStack(alignment: .top) {
            switch page {
            case .monitor:
                MonitorPage(monitor: monitor, connection: connection, tester: tester,
                            preferences: preferences, openSettings: { show(.settings) }, quit: quit)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .settings:
                SettingsPage(preferences: preferences, loginItem: loginItem, back: { show(.monitor) })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(width: Theme.panelSize.width, height: Theme.panelSize.height, alignment: .top)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .panelSurface(preferences.glassStyle, dark: colorScheme == .dark)
    }

    private func show(_ page: PanelPage) {
        withAnimation(.smooth(duration: 0.32)) { self.page = page }
    }
}
