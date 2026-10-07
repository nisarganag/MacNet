import Foundation
import ServiceManagement
import Testing
@testable import MacNetCore

@Suite struct LoginItemAdviceText {
    let installed = URL(fileURLWithPath: "/Applications/MacNet.app")
    let downloaded = URL(fileURLWithPath: "/Users/someone/Downloads/MacNet.app")

    /// macOS 26+ reports `.notFound` for an app that simply hasn't registered
    /// yet — measured from /Applications on the owner's Mac. It must not be
    /// read as "the app is in the wrong place".
    @Test(arguments: [SMAppService.Status.notFound, .notRegistered, .enabled])
    func installedAppNeedsNoAdvice(_ status: SMAppService.Status) {
        #expect(LoginItemAdvice.message(status: status, appURL: installed, error: nil) == nil)
    }

    @Test func appOutsideApplicationsIsAskedToMove() {
        let message = LoginItemAdvice.message(status: .notFound, appURL: downloaded, error: nil)
        #expect(message?.contains("Applications") == true)
    }

    /// Registered from wherever it is, it already works there.
    @Test func enabledAppOutsideApplicationsNeedsNoAdvice() {
        #expect(LoginItemAdvice.message(status: .enabled, appURL: downloaded, error: nil) == nil)
    }

    @Test func pendingApprovalPointsToSystemSettings() {
        let message = LoginItemAdvice.message(status: .requiresApproval, appURL: installed, error: nil)
        #expect(message?.contains("System Settings") == true)
    }

    @Test func aRegistrationErrorWins() {
        #expect(LoginItemAdvice.message(status: .notFound, appURL: installed, error: "Operation not permitted")
                == "Operation not permitted")
    }

    @Test(arguments: [
        ("/Applications/MacNet.app", true),
        ("/Applications/Utilities/MacNet.app", true),
        ("/Users/someone/Applications/MacNet.app", true),
        ("/Users/someone/Desktop/MacNet.app", false),
        ("/Applications Old/MacNet.app", false),
    ])
    func recognisesApplicationsFolders(_ path: String, _ expected: Bool) {
        #expect(LoginItemAdvice.isInApplicationsFolder(URL(fileURLWithPath: path), home: "/Users/someone") == expected)
    }
}
