import Foundation
import Testing
@testable import MacNetCore

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct NetworkQualityParsing {
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    /// `nq-success.json` is a real `networkQuality -c` run from the owner's Mac.
    @Test func parsesASuccessfulRun() throws {
        let result = try NetworkQualityParser.parse(json: fixture("nq-success.json"), summary: "", date: date)
        #expect(result.downloadBitsPerSecond == 62_774_924)
        #expect(result.uploadBitsPerSecond == 45_285_156)
        #expect(abs((result.responsivenessRPM ?? 0) - 67.295) < 0.01)
        #expect(abs((result.idleLatencyMilliseconds ?? 0) - 39.351) < 0.01)
        #expect(result.interfaceName == "en0")
        #expect(result.endpoint == "edge-bx-001.aaplimg.com")
        #expect(result.date == date)
        #expect(result.responsivenessRating == nil)
    }

    /// The JSON has no verdict; Apple's Low/Medium/High only appears in the
    /// human summary the tool prints alongside it.
    @Test func takesApplesRatingFromTheSummary() throws {
        let summary = String(decoding: try fixture("nq-summary.txt"), as: UTF8.self)
        let result = try NetworkQualityParser.parse(json: fixture("nq-success.json"), summary: summary, date: date)
        #expect(result.responsivenessRating == "Low")
    }

    @Test func ignoresPerDirectionRatings() throws {
        let summary = "Uplink Responsiveness: High (20 milliseconds | 3000 RPM)\n"
        let result = try NetworkQualityParser.parse(json: fixture("nq-success.json"), summary: summary, date: date)
        #expect(result.responsivenessRating == nil)
    }

    /// networkQuality exits 0 even when it fails, reporting the error in JSON.
    @Test func reportsToolErrors() throws {
        #expect(throws: SpeedTestError.tool(code: -1003, domain: "NSURLErrorDomain")) {
            try NetworkQualityParser.parse(json: fixture("nq-error.json"), summary: "", date: date)
        }
    }

    @Test func toolErrorsReadAsSentences() {
        let dns = SpeedTestError.tool(code: -1003, domain: "NSURLErrorDomain").errorDescription ?? ""
        let offline = SpeedTestError.tool(code: -1009, domain: "NSURLErrorDomain").errorDescription ?? ""
        let unknown = SpeedTestError.tool(code: 42, domain: "SomeDomain").errorDescription ?? ""
        #expect(!dns.isEmpty)
        #expect(offline.localizedCaseInsensitiveContains("offline"))
        #expect(!unknown.isEmpty)
    }

    @Test func emptyOutputIsNoOutput() {
        #expect(throws: SpeedTestError.noOutput) {
            try NetworkQualityParser.parse(json: Data(), summary: "", date: date)
        }
    }

    @Test(arguments: ["{}", "not json", #"{"dl_throughput": 1000}"#])
    func incompleteOutputIsMalformed(_ text: String) {
        #expect(throws: SpeedTestError.malformed) {
            try NetworkQualityParser.parse(json: Data(text.utf8), summary: "", date: date)
        }
    }

    /// The last result is persisted between launches.
    @Test func resultRoundTripsThroughCodable() throws {
        let summary = String(decoding: try fixture("nq-summary.txt"), as: UTF8.self)
        let result = try NetworkQualityParser.parse(json: fixture("nq-success.json"), summary: summary, date: date)
        let decoded = try JSONDecoder().decode(SpeedTestResult.self, from: JSONEncoder().encode(result))
        #expect(decoded == result)
    }
}
