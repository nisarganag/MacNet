import ServiceManagement

/// The start-at-login switch's state: the system's status plus the last
/// registration error, if any.
public struct LoginItemState: Equatable, Sendable {
    public private(set) var status: SMAppService.Status
    public private(set) var error: String?

    public init(status: SMAppService.Status) {
        self.status = status
    }

    /// A fresh reading of the system status. An earlier error is dropped once
    /// the status has moved: the user fixed things elsewhere (System
    /// Settings), so the old message no longer describes reality.
    public mutating func update(status newStatus: SMAppService.Status) {
        if newStatus != status { error = nil }
        status = newStatus
    }

    public mutating func failed(_ message: String, status newStatus: SMAppService.Status) {
        status = newStatus
        error = message
    }

    public mutating func succeeded(status newStatus: SMAppService.Status) {
        status = newStatus
        error = nil
    }
}
