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
}
