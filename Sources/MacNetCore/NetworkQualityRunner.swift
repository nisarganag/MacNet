import Foundation

/// Runs Apple's `networkQuality` once and returns the parsed result.
///
/// Cancelling the calling task terminates the process — merely abandoning it
/// would leave the tool saturating the connection for the rest of its run.
public struct NetworkQualityRunner: Sendable {
    public static let systemTool = URL(fileURLWithPath: "/usr/bin/networkQuality")

    public let executable: URL

    public init(executable: URL = NetworkQualityRunner.systemTool) {
        self.executable = executable
    }

    public func run() async throws -> SpeedTestResult {
        try Task.checkCancellation()
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacNet-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: output) }

        let child = Child(executable: executable, jsonOutput: output)
        try child.launch()
        let summary = await withTaskCancellationHandler {
            await child.waitForExit()
        } onCancel: {
            child.terminate()
        }
        if child.wasKilled { throw CancellationError() }

        let json = (try? Data(contentsOf: output)) ?? Data()
        return try NetworkQualityParser.parse(json: json, summary: summary, date: Date())
    }
}

/// Owns the process and its stdout pipe. Process and Pipe aren't Sendable,
/// but every use here is either before launch or one of Process's
/// thread-safe operations (terminate, waitUntilExit), so the box is honest.
private final class Child: @unchecked Sendable {
    private let process = Process()
    private let stdout = Pipe()

    init(executable: URL, jsonOutput: URL) {
        process.executableURL = executable
        // Attached form on purpose: `-c` takes an OPTIONAL filename, so as a
        // separate argument the path is ignored and the JSON goes to stdout.
        // Given a file, the tool writes JSON there AND prints its human
        // summary — the only place Apple's responsiveness rating appears.
        process.arguments = ["-c" + jsonOutput.path]
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
    }

    func launch() throws {
        do { try process.run() } catch { throw SpeedTestError.unavailable }
    }

    /// Drains stdout to EOF before reaping, off the caller's thread, so a
    /// chatty child can never block on a full pipe while we wait for it.
    func waitForExit() async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: String(decoding: data, as: UTF8.self))
            }
        }
    }

    func terminate() {
        if process.isRunning { process.terminate() }
    }

    var wasKilled: Bool { process.terminationReason == .uncaughtSignal }
}
