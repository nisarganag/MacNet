import Foundation
import MacNetCore
import Observation
import ServiceManagement

/// Start at login through `SMAppService` rather than a LaunchAgent plist, so
/// MacNet appears by name in System Settings ▸ General ▸ Login Items — where
/// people actually look to turn it off.
///
/// The switch always reflects the system's real status, never a remembered
/// bool: the user can revoke it from System Settings at any time.
@MainActor @Observable
final class LoginItem {
    private(set) var state = LoginItemState(status: SMAppService.mainApp.status)

    var status: SMAppService.Status { state.status }

    /// `requiresApproval` counts as on: the registration exists and only
    /// waits for the user's OK, so showing "off" would invite a second click.
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    var statusText: String? {
        LoginItemAdvice.message(status: status, appURL: Bundle.main.bundleURL, error: state.error)
    }

    /// Re-reads the system status; an old error clears once it has changed.
    func refresh() {
        state.update(status: SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            state.succeeded(status: SMAppService.mainApp.status)
        } catch {
            state.failed(error.localizedDescription, status: SMAppService.mainApp.status)
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
