import Testing
import Foundation
@testable import SwiftWebScraper

/// Real-network checks of the default client. Off unless `SWIFTWEBSCRAPER_LIVE` is set, because
/// they depend on the network and on third-party sites. CI sets it on Linux, where the default
/// client's behavior is the open question.
@Suite(
    "Live network",
    .enabled(if: ProcessInfo.processInfo.environment["SWIFTWEBSCRAPER_LIVE"] != nil)
)
struct LiveNetworkTests {

    @Test("The default client fetches a public HTTPS page")
    func fetchesPublicPage() async throws {
        let url = try #require(URL(string: "https://example.com"))
        let response = try await URLSessionHTTPClient().fetch(url: url)
        #expect(response.statusCode == 200)
        #expect(String(data: response.body, encoding: .utf8)?.contains("Example Domain") == true)
    }

    @Test("The default client refuses a loopback URL without connecting")
    func refusesLoopback() async throws {
        let url = try #require(URL(string: "https://127.0.0.1:9/"))
        await #expect(throws: ScraperError.self) {
            _ = try await URLSessionHTTPClient().fetch(url: url)
        }
    }

    @Test("The default client reports a name that does not resolve as a network error")
    func unresolvableName() async throws {
        let url = try #require(URL(string: "https://no-such-host.invalid"))
        do {
            _ = try await URLSessionHTTPClient().fetch(url: url)
            Issue.record("expected an error")
        } catch let error as ScraperError {
            guard case .networkError = error else {
                Issue.record("expected networkError, got \(error)")
                return
            }
        }
    }
}
