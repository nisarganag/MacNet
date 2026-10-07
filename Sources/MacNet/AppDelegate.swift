import AppKit
import MacNetCore
import Observation
import os
import SwiftUI

private let log = Logger(subsystem: "com.nisarganag.macnet", category: "app")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    let loginItem = LoginItem()
    let connection = ConnectionMonitor()
    let speedTester = SpeedTester()
    private(set) lazy var monitor = NetworkMonitor(interval: preferences.updateInterval)

    private var statusItem: StatusItemController?
    private var activity: NSObjectProtocol?
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App Nap would stretch a 1 s timer to tens of seconds for a windowless
        // app — which is exactly what a menu bar app is. Deliberately allowing
        // idle sleep: a network monitor must never keep the Mac awake.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep], reason: "Live network speed in the menu bar")
        quitCleanlyOnSIGTERM()
        log.notice("MacNet started: \(AppInfo.versionDescription, privacy: .public)")

        connection.start()
        statusItem = StatusItemController { [unowned self] page in
            AnyView(PanelView(monitor: monitor, connection: connection, tester: speedTester,
                              preferences: preferences, loginItem: loginItem, page: page,
                              quit: { NSApp.terminate(nil) }))
        }
        monitor.onSample = { [weak self] rate in
            guard let self else { return }
            statusItem?.show(rate, style: preferences.unitStyle)
        }
        monitor.start()
        followPreferences()
        runDebugLaunchActions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        speedTester.cancel()
    }

    /// Opening MacNet again — from Applications, Spotlight or Launchpad —
    /// shows the panel. When the menu bar is full, or a manager such as
    /// Bartender hides the item, this is the only way back to the panel, its
    /// settings and Quit.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.openPanel(.monitor)
        return false
    }

    /// Re-arms itself after every change: Observation reports one change per
    /// registration.
    private func followPreferences() {
        withObservationTracking {
            _ = preferences.updateInterval
            _ = preferences.unitStyle
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.monitor.setInterval(self.preferences.updateInterval)
                // Redraw now rather than at the next sample, up to 5 s away.
                self.statusItem?.show(self.monitor.current, style: self.preferences.unitStyle)
                self.followPreferences()
            }
        }
    }

    /// `make install` (and logout) send SIGTERM, whose default action kills
    /// the process on the spot — skipping applicationWillTerminate and
    /// orphaning a running speed test. Route it through a normal quit instead.
    private func quitCleanlyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        source.resume()
        terminationSignal = source
    }

    /// Developer hooks for verifying behaviour from the command line, e.g.
    /// `MacNet.app/Contents/MacOS/MacNet -MacNetDebugAction speedtest` or
    /// `-MacNetDebugPanel settings`.
    /// Launch arguments live only in the volatile argument domain, so nothing
    /// here persists or can trigger on a normal launch.
    private func runDebugLaunchActions() {
        if let page = UserDefaults.standard.string(forKey: "MacNetDebugPanel") {
            // After the status bar has laid the new item out, so the panel
            // can be positioned under it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                MainActor.assumeIsolated {
                    self?.statusItem?.openPanel(page == "settings" ? .settings : .monitor)
                }
            }
        }
        switch UserDefaults.standard.string(forKey: "MacNetDebugAction") {
        case "speedtest":
            speedTester.start()
        case "speedtest-cancel":
            speedTester.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                MainActor.assumeIsolated { self?.speedTester.cancel() }
            }
        default:
            break
        }
    }
}
