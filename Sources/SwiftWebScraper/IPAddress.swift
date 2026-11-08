import Foundation

/// An IPv4 or IPv6 address as raw bytes, with a public/non-public classification.
///
/// "Public" means globally routable. Loopback, private, link-local, carrier-grade NAT,
/// documentation, benchmarking, multicast and reserved ranges are all non-public. IPv6 forms
/// that embed an IPv4 address (IPv4-mapped, NAT64, 6to4) are classified by the address they embed.
public enum IPAddress: Sendable, Equatable {
    /// Four bytes, most significant first.
    case v4([UInt8])
    /// Sixteen bytes, most significant first.
    case v6([UInt8])

    /// Parses a host string as an IP literal, or returns `nil` if it is a name.
    ///
    /// Accepts bracketed IPv6 (`[::1]`) and the legacy IPv4 spellings that resolvers also accept
    /// (decimal `2130706433`, hex `0x7f.0.0.1`, octal `0177.0.0.1`, short `127.1`), so none of them
    /// can be used to disguise a loopback address.
    public static func parse(_ host: String) -> IPAddress? {
        var text = host
        if text.hasPrefix("["), text.hasSuffix("]") {
            text = String(text.dropFirst().dropLast())
        }
        if let v6 = parseIPv6(text) { return v6 }
        return parseIPv4(text)
    }

    /// Whether the address is globally routable.
    public var isPublic: Bool {
        switch self {
        case .v4(let bytes):
            return Self.isPublicIPv4(bytes)
        case .v6(let bytes):
            return Self.isPublicIPv6(bytes)
        }
    }

    // MARK: - Parsing

    private static func parseIPv6(_ text: String) -> IPAddress? {
        guard text.contains(":"), !text.contains("%") else { return nil }

        var groups = text.components(separatedBy: ":")
        // A trailing dotted quad (::ffff:127.0.0.1) stands for the last two 16-bit groups.
        if let last = groups.last, last.contains(".") {
            guard let quad = strictDottedQuad(last) else { return nil }
            groups.removeLast()
            groups.append(String(UInt16(quad[0]) << 8 | UInt16(quad[1]), radix: 16))
            groups.append(String(UInt16(quad[2]) << 8 | UInt16(quad[3]), radix: 16))
        }

        let joined = groups.joined(separator: ":")
        let halves = joined.components(separatedBy: "::")
        guard halves.count <= 2 else { return nil }

        func words(_ part: String) -> [UInt16]? {
            if part.isEmpty { return [] }
            var result: [UInt16] = []
            for group in part.components(separatedBy: ":") {
                guard (1...4).contains(group.count), let word = UInt16(group, radix: 16) else { return nil }
                result.append(word)
            }
            return result
        }

        guard let head = words(halves[0]) else { return nil }
        var all = head
        if halves.count == 2 {
            guard let tail = words(halves[1]), head.count + tail.count <= 7 else { return nil }
            all += [UInt16](repeating: 0, count: 8 - head.count - tail.count) + tail
        }
        guard all.count == 8 else { return nil }
        return .v6(all.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xff)] })
    }

    private static func strictDottedQuad(_ text: String) -> [UInt8]? {
        let parts = text.components(separatedBy: ".")
        guard parts.count == 4 else { return nil }
        let octets = parts.compactMap { UInt8($0) }
        return octets.count == 4 ? octets : nil
    }

    private static func parseIPv4(_ text: String) -> IPAddress? {
        var address = in_addr()
        guard inet_aton(text, &address) != 0 else { return nil }
        // s_addr holds the address in network byte order; reading it big-endian gives the value.
        let value = UInt32(bigEndian: address.s_addr)
        return .v4([
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value)
        ])
    }

    // MARK: - Classification

    private static func isPublicIPv4(_ b: [UInt8]) -> Bool {
        guard b.count == 4 else { return false }
        switch (b[0], b[1], b[2]) {
        case (0, _, _), (10, _, _), (127, _, _): return false
        case (100, 64...127, _): return false          // carrier-grade NAT
        case (169, 254, _): return false               // link-local, cloud metadata
        case (172, 16...31, _): return false
        case (192, 0, 0), (192, 0, 2): return false    // IETF protocol, documentation
        case (192, 168, _): return false
        case (198, 18...19, _): return false           // benchmarking
        case (198, 51, 100), (203, 0, 113): return false
        case (224..., _, _): return false              // multicast, reserved, broadcast
        default: return true
        }
    }

    private static func isPublicIPv6(_ b: [UInt8]) -> Bool {
        guard b.count == 16 else { return false }
        let leadingZeros = b[0..<10].allSatisfy { $0 == 0 }

        // IPv4-mapped (::ffff:a.b.c.d): judged by the embedded IPv4 address.
        if leadingZeros, b[10] == 0xff, b[11] == 0xff {
            return isPublicIPv4(Array(b[12..<16]))
        }
        // Unspecified (::) and loopback (::1).
        if b[0..<15].allSatisfy({ $0 == 0 }), b[15] <= 1 { return false }
        // NAT64 (64:ff9b::/96): judged by the embedded IPv4 address.
        if b[0] == 0x00, b[1] == 0x64, b[2] == 0xff, b[3] == 0x9b, b[4..<12].allSatisfy({ $0 == 0 }) {
            return isPublicIPv4(Array(b[12..<16]))
        }
        // 6to4 (2002::/16): the IPv4 address sits in bytes 2...5.
        if b[0] == 0x20, b[1] == 0x02 {
            return isPublicIPv4(Array(b[2..<6]))
        }
        // Documentation (2001:db8::/32).
        if b[0] == 0x20, b[1] == 0x01, b[2] == 0x0d, b[3] == 0xb8 { return false }
        // Unique local fc00::/7, link-local fe80::/10, deprecated site-local fec0::/10, multicast ff00::/8.
        if b[0] & 0xfe == 0xfc { return false }
        if b[0] == 0xfe, b[1] & 0xc0 == 0x80 || b[1] & 0xc0 == 0xc0 { return false }
        if b[0] == 0xff { return false }
        return true
    }
}
