import Darwin
import Foundation
import Testing
@testable import MacNetCore

/// Each test swaps `networkQuality` for a tiny shell script, so the process
/// handling is exercised for real without touching the network.
@Suite struct NetworkQualityRunning {
    private func scratchDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("macnet-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fakeTool(_ body: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("networkQuality")
        try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func fixture(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    }

    /// The JSON path has to travel in the attached `-c<file>` form; the
    /// summary on stdout is read at the same time for Apple's rating.
    @Test func readsTheOutputFileAndTheSummary() async throws {
        let dir = try scratchDirectory()
        let tool = try fakeTool("""
            cp '\(try fixture("nq-success.json").path)' "${1#-c}"
            echo 'Responsiveness: Medium (50.000 milliseconds | 1200 RPM)'
            """, in: dir)
        let result = try await NetworkQualityRunner(executable: tool).run()
        #expect(result.downloadBitsPerSecond == 62_774_924)
        #expect(result.uploadBitsPerSecond == 45_285_156)
        #expect(result.responsivenessRating == "Medium")
    }

    @Test func reportsFailuresTheToolWritesToItsJSON() async throws {
        let dir = try scratchDirectory()
        let tool = try fakeTool("cp '\(try fixture("nq-error.json").path)' \"${1#-c}\"", in: dir)
        await #expect(throws: SpeedTestError.tool(code: -1003, domain: "NSURLErrorDomain")) {
            try await NetworkQualityRunner(executable: tool).run()
        }
    }

    @Test func exitingWithoutWritingAnythingIsNoOutput() async throws {
        let dir = try scratchDirectory()
        let tool = try fakeTool("exit 1", in: dir)
        await #expect(throws: SpeedTestError.noOutput) {
            try await NetworkQualityRunner(executable: tool).run()
        }
    }

    @Test func missingToolIsUnavailable() async {
        let missing = URL(fileURLWithPath: "/nonexistent/networkQuality")
        await #expect(throws: SpeedTestError.unavailable) {
            try await NetworkQualityRunner(executable: missing).run()
        }
        #expect(!(SpeedTestError.unavailable.errorDescription ?? "").isEmpty)
    }

    /// Cancel must kill the process, not just stop waiting for it — an
    /// orphaned networkQuality would keep saturating the link for 30 s.
    @Test func cancellingKillsTheProcess() async throws {
        let dir = try scratchDirectory()
        let pidFile = dir.appendingPathComponent("pid")
        let tool = try fakeTool("echo $$ > '\(pidFile.path)'\nexec sleep 30", in: dir)

        let run = Task { try await NetworkQualityRunner(executable: tool).run() }
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: pidFile.path) {
            try await Task.sleep(for: .milliseconds(20))
        }
        let pidText = try String(contentsOf: pidFile, encoding: .utf8)
        let pid = try #require(pid_t(pidText.trimmingCharacters(in: .whitespacesAndNewlines)))

        let cancelledAt = ContinuousClock.now
        run.cancel()
        await #expect(throws: CancellationError.self) { try await run.value }
        #expect(ContinuousClock.now - cancelledAt < .seconds(5))
        #expect(kill(pid, 0) == -1)
    }
}
