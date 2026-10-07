import ServiceManagement
import Testing
@testable import MacNetCore

@Suite struct LoginItemStateTracking {
    /// The error stays while nothing has changed, and goes once the status
    /// moves — the user fixed things in System Settings, so the old message
    /// no longer describes reality.
    @Test func aFailureShowsUntilTheStatusChanges() {
        var state = LoginItemState(status: .notRegistered)
        state.failed("Operation not permitted", status: .notRegistered)
        state.update(status: .notRegistered)
        #expect(state.error == "Operation not permitted")
        state.update(status: .enabled)
        #expect(state.error == nil)
        #expect(state.status == .enabled)
    }

    @Test func successClearsAnEarlierFailure() {
        var state = LoginItemState(status: .notRegistered)
        state.failed("Operation not permitted", status: .notRegistered)
        state.succeeded(status: .enabled)
        #expect(state.error == nil)
        #expect(state.status == .enabled)
    }
}
