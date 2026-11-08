import Testing
import Foundation
@testable import SwiftWebScraper

/// A resolver that answers from a fixed table, so tests never touch the network.
struct StubResolver: HostResolver {
    let table: [String: [IPAddress]]

    func resolve(_ host: String) async throws -> [IPAddress] {
        guard let addresses = table[host] else {
            throw ScraperError.networkError(url: host, underlying: "no such host")
        }
        return addresses
    }
}

@Suite("Resolving validation")
struct ResolvingValidationTests {
    let resolver = StubResolver(table: [
        "public.example": [.v4([93, 184, 216, 34])],
        "rebind.example": [.v4([10, 0, 0, 5])],
        "mixed.example": [.v4([93, 184, 216, 34]), .v4([169, 254, 169, 254])],
        "v6.example": [.v6([0xfd, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])]
    ])

    @Test("A name that resolves to a public address passes")
    func passes() async throws {
        let url = try #require(URL(string: "https://public.example/page"))
        try await URLValidator.validateResolvingHost(of: url, using: resolver)
    }

    @Test("A public name resolving to a private address is rejected", arguments: [
        "https://rebind.example", "https://mixed.example", "https://v6.example"
    ])
    func rejectsRebind(_ string: String) async throws {
        let url = try #require(URL(string: string))
        await #expect(throws: ScraperError.self) {
            try await URLValidator.validateResolvingHost(of: url, using: resolver)
        }
    }

    @Test("A name that does not resolve surfaces as a network error, not an SSRF refusal")
    func unresolvable() async throws {
        let url = try #require(URL(string: "https://nowhere.example"))
        do {
            try await URLValidator.validateResolvingHost(of: url, using: resolver)
            Issue.record("expected an error")
        } catch let error as ScraperError {
            guard case .networkError = error else {
                Issue.record("expected networkError, got \(error)")
                return
            }
        }
    }

    @Test("The string checks still run before any lookup")
    func stringChecksFirst() async throws {
        let url = try #require(URL(string: "https://127.0.0.1"))
        await #expect(throws: ScraperError.self) {
            try await URLValidator.validateResolvingHost(of: url, using: resolver)
        }
    }

    @Test("The system resolver answers for a numeric host without the network")
    func systemResolverNumeric() async throws {
        let addresses = try await SystemHostResolver().resolve("8.8.8.8")
        #expect(addresses == [.v4([8, 8, 8, 8])])
    }
}

@Suite("IPAddress parsing")
struct IPAddressParsingTests {
    private static let loopback: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]

    @Test("Every spelling of IPv6 loopback parses to the same bytes", arguments: [
        "::1", "[::1]", "0:0:0:0:0:0:0:1", "0000:0000:0000:0000:0000:0000:0000:0001"
    ])
    func ipv6Loopback(_ text: String) {
        #expect(IPAddress.parse(text) == .v6(Self.loopback))
    }

    @Test("An IPv4-mapped address keeps its IPv4 bytes")
    func mapped() {
        let expected: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, 127, 0, 0, 1]
        #expect(IPAddress.parse("::ffff:127.0.0.1") == .v6(expected))
    }

    @Test("A unique-local prefix parses")
    func uniqueLocal() {
        let expected: [UInt8] = [0xfd, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        #expect(IPAddress.parse("fd00::") == .v6(expected))
    }

    @Test("Strings that are not addresses parse to nil", arguments: [
        "example.com", "fcc.gov", "fdic.gov", "1::2::3", "12345::1", ":::", "fe80::1%en0", "::ffff:300.0.0.1"
    ])
    func notAnAddress(_ text: String) {
        #expect(IPAddress.parse(text) == nil)
    }
}
