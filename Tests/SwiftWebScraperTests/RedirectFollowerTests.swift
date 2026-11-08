import Testing
import Foundation
@testable import SwiftWebScraper

/// Records every URL requested and replays scripted responses.
actor HopLog {
    private(set) var urls: [URL] = []
    func record(_ url: URL) { urls.append(url) }
}

@Suite("RedirectFollower")
struct RedirectFollowerTests {
    let resolver = StubResolver(table: [
        "a.example": [.v4([93, 184, 216, 34])],
        "b.example": [.v4([93, 184, 216, 35])]
    ])

    private func redirect(to location: String) -> HTTPResponse {
        HTTPResponse(statusCode: 302, headers: ["Location": location], body: Data())
    }

    @Test("A response that is not a redirect is returned untouched")
    func noRedirect() async throws {
        let url = try #require(URL(string: "https://a.example/"))
        let response = try await RedirectFollower.fetch(url, resolver: resolver) { _ in
            HTTPResponse(statusCode: 200, body: Data("ok".utf8))
        }
        #expect(response.statusCode == 200)
        #expect(response.body == Data("ok".utf8))
    }

    @Test("An absolute redirect to another public host is followed")
    func followsAbsolute() async throws {
        let url = try #require(URL(string: "https://a.example/"))
        let log = HopLog()
        let response = try await RedirectFollower.fetch(url, resolver: resolver) { hop in
            await log.record(hop)
            return hop.host == "a.example" ? self.redirect(to: "https://b.example/landing") : HTTPResponse(statusCode: 200)
        }
        #expect(response.statusCode == 200)
        #expect(await log.urls.map(\.absoluteString) == ["https://a.example/", "https://b.example/landing"])
    }

    @Test("A relative Location is resolved against the current URL")
    func followsRelative() async throws {
        let url = try #require(URL(string: "https://a.example/old/page"))
        let log = HopLog()
        _ = try await RedirectFollower.fetch(url, resolver: resolver) { hop in
            await log.record(hop)
            return hop.path == "/old/page" ? self.redirect(to: "/new") : HTTPResponse(statusCode: 200)
        }
        #expect(await log.urls.last?.absoluteString == "https://a.example/new")
    }

    @Test("A redirect to a private address is refused before it is requested", arguments: [
        "https://169.254.169.254/latest/meta-data", "https://localhost:8080/", "https://[::1]/"
    ])
    func refusesPrivateTarget(_ target: String) async throws {
        let url = try #require(URL(string: "https://a.example/"))
        let log = HopLog()
        await #expect(throws: ScraperError.self) {
            _ = try await RedirectFollower.fetch(url, resolver: resolver) { hop in
                await log.record(hop)
                return self.redirect(to: target)
            }
        }
        #expect(await log.urls.count == 1)
    }

    @Test("A redirect to a name that resolves privately is refused")
    func refusesRebindTarget() async throws {
        let rebinding = StubResolver(table: [
            "a.example": [.v4([93, 184, 216, 34])],
            "evil.example": [.v4([10, 0, 0, 5])]
        ])
        let url = try #require(URL(string: "https://a.example/"))
        await #expect(throws: ScraperError.self) {
            _ = try await RedirectFollower.fetch(url, resolver: rebinding) { _ in
                self.redirect(to: "https://evil.example/")
            }
        }
    }

    @Test("A redirect loop stops at the limit with a network error")
    func stopsAtLimit() async throws {
        let url = try #require(URL(string: "https://a.example/"))
        let log = HopLog()
        do {
            _ = try await RedirectFollower.fetch(url, maxRedirects: 3, resolver: resolver) { hop in
                await log.record(hop)
                return self.redirect(to: "https://a.example/again")
            }
            Issue.record("expected an error")
        } catch let error as ScraperError {
            guard case .networkError(_, let underlying) = error else {
                Issue.record("expected networkError, got \(error)")
                return
            }
            #expect(underlying.contains("redirect"))
        }
        #expect(await log.urls.count == 4)
    }

    @Test("A redirect status with no Location is returned as the response")
    func missingLocation() async throws {
        let url = try #require(URL(string: "https://a.example/"))
        let response = try await RedirectFollower.fetch(url, resolver: resolver) { _ in
            HTTPResponse(statusCode: 302)
        }
        #expect(response.statusCode == 302)
    }

    @Test("The starting URL is validated too")
    func validatesStart() async throws {
        let url = try #require(URL(string: "https://10.0.0.1/"))
        await #expect(throws: ScraperError.self) {
            _ = try await RedirectFollower.fetch(url, resolver: resolver) { _ in HTTPResponse(statusCode: 200) }
        }
    }
}
