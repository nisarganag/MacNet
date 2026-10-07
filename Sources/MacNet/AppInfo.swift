import Foundation

enum AppInfo {
    static let repository = URL(string: "https://github.com/nisarganag/MacNet")!
    static let releases = URL(string: "https://github.com/nisarganag/MacNet/releases")!

    /// "Version 1.0.0 (12)" in a bundled build — version from the release
    /// tag, build from the commit count, both stamped by `make bundle`.
    static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        guard let version = info?["CFBundleShortVersionString"] as? String else {
            return "Development build"
        }
        guard let build = info?["CFBundleVersion"] as? String else { return "Version \(version)" }
        return "Version \(version) (\(build))"
    }
}
