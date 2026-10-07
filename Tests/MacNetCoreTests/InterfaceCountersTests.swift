import Darwin
import Foundation
import Testing
@testable import MacNetCore

@Suite struct SystemInterfaceCounters {
    @Test func defaultFilterExcludesLoopback() throws {
        let counters = try #require(InterfaceCounters.snapshot()).counters
        #expect(counters["lo0"] == nil)
        #expect(counters.keys.allSatisfy(InterfaceFilter.counts))
    }

    @Test func customFilterSelectsExactlyWhatItAccepts() throws {
        let counters = try #require(InterfaceCounters.snapshot { $0 == "lo0" }).counters
        #expect(Array(counters.keys) == ["lo0"])
    }

    @Test func countersAndClockNeverGoBackwards() throws {
        let first = try #require(InterfaceCounters.snapshot { _ in true })
        let second = try #require(InterfaceCounters.snapshot { _ in true })
        #expect(second.uptime >= first.uptime)
        for (name, before) in first.counters {
            guard let after = second.counters[name] else { continue }
            #expect(after.received >= before.received, "\(name) received")
            #expect(after.sent >= before.sent, "\(name) sent")
        }
    }

    /// Proves the counters come from the right fields at the right offsets:
    /// traffic this test generates itself must appear in lo0's sent bytes.
    @Test func loopbackTrafficShowsUpInTheCounters() throws {
        let loopbackOnly: (String) -> Bool = { $0 == "lo0" }
        let before = try #require(InterfaceCounters.snapshot(filter: loopbackOnly)?.counters["lo0"])
        try sendLoopbackUDP(totalBytes: 200_000)
        let after = try #require(InterfaceCounters.snapshot(filter: loopbackOnly)?.counters["lo0"])
        #expect(after.sent - before.sent >= 200_000)
        #expect(after.received - before.received >= 200_000)
    }
}

/// Fires UDP datagrams at the discard port on 127.0.0.1. Nothing needs to be
/// listening: an unconnected UDP socket never sees the port-unreachable reply,
/// and the bytes cross lo0 either way.
private func sendLoopbackUDP(totalBytes: Int) throws {
    let fd = socket(AF_INET, SOCK_DGRAM, 0)
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    defer { close(fd) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(9).bigEndian
    address.sin_addr.s_addr = inet_addr("127.0.0.1")

    let payload = [UInt8](repeating: 0x5A, count: 1_000)
    var sent = 0
    while sent < totalBytes {
        let n = payload.withUnsafeBytes { bytes in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, bytes.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard n > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        sent += n
    }
}
