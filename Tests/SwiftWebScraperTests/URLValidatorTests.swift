import Testing
import Foundation
@testable import SwiftWebScraper

@Suite("URLValidator")
struct URLValidatorTests {

    @Test("Public http and https URLs are accepted", arguments: [
        "https://example.com", "https://example.com/path?q=1", "https://sub.example.co.uk"
    ])
    func accepts(_ string: String) {
        #expect(URLValidator.validatedURL(string)?.absoluteString == string)
    }

    @Test("Loopback, private, link-local and metadata hosts are rejected", arguments: [
        "https://localhost", "https://127.0.0.1", "https://10.1.2.3", "https://192.168.0.5",
        "https://172.16.0.1", "https://169.254.169.254", "https://0.0.0.0", "https://metadata.google.internal"
    ])
    func rejectsPrivate(_ string: String) {
        #expect(URLValidator.validatedURL(string) == nil)
    }

    @Test("Non-http schemes are rejected with an unsafeURL error")
    func rejectsScheme() throws {
        let url = try #require(URL(string: "file:///etc/passwd"))
        #expect(throws: ScraperError.self) { try URLValidator.validatePublicURL(url) }
    }

    @Test("A string that is not a URL yields nil")
    func notAURL() {
        #expect(URLValidator.validatedURL("") == nil)
    }

    @Test("Hostnames that merely start with fc or fd are not mistaken for IPv6 unique-local", arguments: [
        "https://fcc.gov", "https://fdic.gov", "https://fda.gov"
    ])
    func acceptsFcFdHostnames(_ string: String) {
        #expect(URLValidator.validatedURL(string)?.absoluteString == string)
    }

    @Test("Reserved addresses beyond the common private ranges are rejected", arguments: [
        "https://[fc00::1]", "https://[fd12:3456::1]", "https://[fe80::1]", "https://[::1]",
        "https://[::ffff:127.0.0.1]", "https://[::ffff:10.0.0.1]", "https://[64:ff9b::a00:1]",
        "https://100.64.0.1", "https://198.18.0.1", "https://192.0.0.1", "https://224.0.0.1",
        "https://255.255.255.255", "https://sub.localhost", "https://printer.local"
    ])
    func rejectsReserved(_ string: String) {
        #expect(URLValidator.validatedURL(string) == nil)
    }

    @Test("Alternate spellings of loopback are rejected", arguments: [
        "https://2130706433", "https://0x7f.0.0.1", "https://0177.0.0.1", "https://127.1"
    ])
    func rejectsAlternateLoopback(_ string: String) {
        #expect(URLValidator.validatedURL(string) == nil)
    }

    @Test("Public IP literals are accepted", arguments: [
        "https://8.8.8.8", "https://[2606:4700:4700::1111]"
    ])
    func acceptsPublicLiterals(_ string: String) {
        #expect(URLValidator.validatedURL(string)?.absoluteString == string)
    }
}
