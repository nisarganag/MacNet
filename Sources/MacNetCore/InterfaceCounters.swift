import Darwin
import Foundation

/// Reads per-interface byte counters from the kernel's routing socket table.
///
/// `NET_RT_IFLIST2` rather than `getifaddrs()`: the latter reports `if_data`,
/// whose byte counters are 32-bit and wrap every 4 GB — a few minutes of a
/// fast download. `if_msghdr2` carries `if_data64`, which does not.
public enum InterfaceCounters {
    /// Nil when the kernel couldn't be read — distinct from a successful
    /// read that simply has no counted interfaces.
    public static func snapshot(filter: (String) -> Bool = InterfaceFilter.counts) -> CounterSnapshot? {
        read(filter: filter).map { CounterSnapshot(counters: $0, uptime: ProcessInfo.processInfo.systemUptime) }
    }

    private static func read(filter: (String) -> Bool) -> [String: InterfaceCounter]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        // Headroom for an interface appearing between the two calls, which
        // would otherwise fail the second one with ENOMEM.
        length += length / 8
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var counters: [String: InterfaceCounter] = [:]
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0, offset + messageLength <= length else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2,
                   messageLength >= MemoryLayout<if_msghdr2>.size {
                    let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let name = linkName(raw, message: message, at: offset, length: messageLength)
                        ?? indexName(message.ifm_index)
                    if let name, filter(name) {
                        counters[name] = InterfaceCounter(received: message.ifm_data.ifi_ibytes,
                                                          sent: message.ifm_data.ifi_obytes)
                    }
                }
                offset += messageLength
            }
        }
        return counters
    }

    /// The interface name from the `sockaddr_dl` that follows the message.
    ///
    /// Read in place because `if_indextoname` re-walks the whole interface
    /// list on every call — once per interface per sample adds up. Only the
    /// common layout is trusted (the link address is the first and only
    /// sockaddr); anything else falls back to the slow path.
    private static func linkName(_ raw: UnsafeRawBufferPointer, message: if_msghdr2,
                                 at offset: Int, length: Int) -> String? {
        let addresses = message.ifm_addrs
        guard addresses & RTA_IFP != 0, addresses & (RTA_IFP - 1) == 0 else { return nil }
        // sockaddr_dl: len, family, index(2), type, nlen, alen, slen, data…
        let start = offset + MemoryLayout<if_msghdr2>.size
        let end = offset + length
        guard start + 8 <= end, Int32(raw[start + 1]) == AF_LINK else { return nil }
        let nameLength = Int(raw[start + 5])
        let nameStart = start + 8
        guard nameLength > 0, nameStart + nameLength <= end else { return nil }
        return String(decoding: UnsafeRawBufferPointer(rebasing: raw[nameStart ..< nameStart + nameLength]),
                      as: UTF8.self)
    }

    private static func indexName(_ index: UInt16) -> String? {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        return name.withUnsafeMutableBufferPointer { buffer in
            guard let cName = if_indextoname(UInt32(index), buffer.baseAddress) else { return nil }
            return String(cString: cName)
        }
    }
}
