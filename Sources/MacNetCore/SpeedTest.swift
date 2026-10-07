import Foundation

/// One completed internet speed test.
public struct SpeedTestResult: Codable, Equatable, Sendable {
    public var downloadBitsPerSecond: Double
    public var uploadBitsPerSecond: Double
    /// Round-trips per minute while the link is saturated — Apple's measure of
    /// how usable the connection stays under load.
    public var responsivenessRPM: Double?
    /// Apple's own verdict ("Low", "Medium" or "High"), taken verbatim from the
    /// tool rather than re-derived from thresholds Apple doesn't publish.
    public var responsivenessRating: String?
    public var idleLatencyMilliseconds: Double?
    public var interfaceName: String?
    public var endpoint: String?
    public var date: Date

    public init(downloadBitsPerSecond: Double, uploadBitsPerSecond: Double, responsivenessRPM: Double?,
                responsivenessRating: String?, idleLatencyMilliseconds: Double?, interfaceName: String?,
                endpoint: String?, date: Date) {
        self.downloadBitsPerSecond = downloadBitsPerSecond
        self.uploadBitsPerSecond = uploadBitsPerSecond
        self.responsivenessRPM = responsivenessRPM
        self.responsivenessRating = responsivenessRating
        self.idleLatencyMilliseconds = idleLatencyMilliseconds
        self.interfaceName = interfaceName
        self.endpoint = endpoint
        self.date = date
    }
}

public enum SpeedTestError: Error, Equatable, LocalizedError {
    /// The tool ran but reported a failure (it still exits 0 when it does).
    case tool(code: Int, domain: String)
    /// The tool is missing or couldn't be launched.
    case unavailable
    case noOutput
    case malformed

    public var errorDescription: String? {
        switch self {
        case let .tool(code, domain):
            if domain == NSURLErrorDomain, let message = Self.urlMessages[code] { return message }
            return NSError(domain: domain, code: code).localizedDescription
        case .unavailable:
            return "macOS's networkQuality tool couldn't be started."
        case .noOutput:
            return "The speed test finished without a result."
        case .malformed:
            return "The speed test's result couldn't be read."
        }
    }

    /// Plain-language versions of the failures people actually hit.
    private static let urlMessages: [Int: String] = [
        NSURLErrorNotConnectedToInternet: "You appear to be offline.",
        NSURLErrorTimedOut: "The speed test server took too long to respond.",
        NSURLErrorCannotFindHost: "Couldn't reach the speed test server. Check your connection or DNS.",
        NSURLErrorDNSLookupFailed: "Couldn't reach the speed test server. Check your connection or DNS.",
        NSURLErrorCannotConnectToHost: "Couldn't connect to the speed test server.",
        NSURLErrorNetworkConnectionLost: "The connection dropped during the test.",
    ]
}

/// Reads the output of Apple's `networkQuality` tool.
public enum NetworkQualityParser {
    private struct Output: Decodable {
        var dlThroughput: Double?
        var ulThroughput: Double?
        var responsiveness: Double?
        var baseRtt: Double?
        var interfaceName: String?
        var testEndpoint: String?
        var errorCode: Int?
        var errorDomain: String?
    }

    /// - Parameters:
    ///   - json: what `networkQuality -c<file>` wrote to the file.
    ///   - summary: what it printed to stdout at the same time — the only
    ///     place Apple's responsiveness rating appears.
    public static func parse(json: Data, summary: String, date: Date) throws -> SpeedTestResult {
        guard !json.isEmpty else { throw SpeedTestError.noOutput }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let output = try? decoder.decode(Output.self, from: json) else { throw SpeedTestError.malformed }
        if let code = output.errorCode {
            throw SpeedTestError.tool(code: code, domain: output.errorDomain ?? "networkQuality")
        }
        guard let download = output.dlThroughput, let upload = output.ulThroughput else {
            throw SpeedTestError.malformed
        }
        return SpeedTestResult(
            downloadBitsPerSecond: download, uploadBitsPerSecond: upload,
            responsivenessRPM: output.responsiveness, responsivenessRating: rating(in: summary),
            idleLatencyMilliseconds: output.baseRtt, interfaceName: output.interfaceName,
            endpoint: output.testEndpoint, date: date)
    }

    /// The word after a line that starts with "Responsiveness:" — the overall
    /// verdict, not the per-direction lines a sequential (`-s`) run prints.
    static func rating(in summary: String) -> String? {
        for line in summary.split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard text.hasPrefix("Responsiveness:") else { continue }
            let word = text.dropFirst("Responsiveness:".count).drop { $0 == " " }.prefix { $0.isLetter }
            return word.isEmpty ? nil : String(word)
        }
        return nil
    }
}
