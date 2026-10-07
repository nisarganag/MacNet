import Foundation
import ServiceManagement

/// What to say beside the start-at-login switch, if anything.
public enum LoginItemAdvice {
    /// - Parameters:
    ///   - status: `SMAppService.mainApp.status`.
    ///   - appURL: where the running app lives (`Bundle.main.bundleURL`).
    ///   - error: the last registration error, if there was one.
    public static func message(status: SMAppService.Status, appURL: URL, error: String?,
                               home: String = NSHomeDirectory()) -> String? {
        if let error { return error }
        if status == .requiresApproval { return "Allow MacNet in System Settings ▸ Login Items." }
        // Where the app lives is the real test for this hint, not `.notFound`:
        // macOS 26+ reports `.notFound` for an app that simply hasn't
        // registered yet, even one sitting in /Applications.
        if status != .enabled, !isInApplicationsFolder(appURL, home: home) {
            return "Move MacNet to the Applications folder to use this."
        }
        return nil
    }

    /// `/Applications` (including subfolders) or `~/Applications`.
    public static func isInApplicationsFolder(_ url: URL, home: String = NSHomeDirectory()) -> Bool {
        let path = url.standardizedFileURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/")
    }
}
