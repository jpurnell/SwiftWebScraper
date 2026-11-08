import Foundation

/// Resolves a hostname to the addresses a connection to it could reach.
///
/// A seam for tests and for callers with their own resolver. The default is ``SystemHostResolver``.
public protocol HostResolver: Sendable {
    /// Returns every address the host resolves to.
    ///
    /// - Throws: ``ScraperError/networkError(url:underlying:)`` if the host cannot be resolved.
    func resolve(_ host: String) async throws -> [IPAddress]
}

/// Resolves hosts with the system resolver (`getaddrinfo`).
public struct SystemHostResolver: HostResolver {
    /// Creates a resolver backed by `getaddrinfo`.
    public init() {}

    /// Looks the host up with `getaddrinfo`, off the cooperative thread pool.
    public func resolve(_ host: String) async throws -> [IPAddress] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(with: Result { try Self.lookup(host) })
            }
        }
    }

    private static func lookup(_ host: String) throws -> [IPAddress] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if canImport(Glibc)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif

        var head: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &head)
        guard status == 0, let first = head else {
            let reason = String(cString: gai_strerror(status))
            throw ScraperError.networkError(url: host, underlying: "DNS resolution failed: \(reason)")
        }
        defer { freeaddrinfo(first) }

        var addresses: [IPAddress] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let entry = cursor {
            guard let address = entry.pointee.ai_addr,
                  let parsed = Self.address(from: address, length: entry.pointee.ai_addrlen) else {
                // An address we cannot read must not be skipped: skipping it would let it pass unchecked.
                throw ScraperError.networkError(url: host, underlying: "DNS returned an address that could not be read")
            }
            addresses.append(parsed)
            cursor = entry.pointee.ai_next
        }
        return addresses
    }

    /// Renders a socket address as numeric text with `getnameinfo`, then parses that text.
    private static func address(from socketAddress: UnsafeMutablePointer<sockaddr>, length: socklen_t) -> IPAddress? {
        var buffer = [CChar](repeating: 0, count: 64)
        let status = getnameinfo(socketAddress, length, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST)
        guard status == 0 else { return nil }
        // Link-local results carry a zone suffix ("fe80::1%en0"); the address is what matters here.
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let text = String(decoding: bytes, as: UTF8.self).components(separatedBy: "%")[0]
        return IPAddress.parse(text)
    }
}
