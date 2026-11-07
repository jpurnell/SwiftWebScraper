import Foundation
@testable import SwiftWebScraper

/// A deterministic mock HTTP client for testing.
///
/// Register canned responses for URLs before making requests.
/// Returns ``ScraperError/fetchFailed(url:statusCode:)`` for unregistered URLs.
actor MockHTTPClient: HTTPClientProtocol {
    private var responses: [String: HTTPResponse] = [:]
    private var errors: [String: any Error] = [:]
    private(set) var requestedURLs: [String] = []

    /// Register a successful response for a URL.
    func register(url: String, response: HTTPResponse) {
        responses[url] = response
    }

    /// Register an error for a URL.
    func register(url: String, error: any Error) {
        errors[url] = error
    }

    nonisolated func fetch(url: URL) async throws -> HTTPResponse {
        let urlString = url.absoluteString
        await recordRequest(urlString)

        if let error = await getError(for: urlString) {
            throw error
        }

        guard let response = await getResponse(for: urlString) else {
            throw ScraperError.fetchFailed(url: urlString, statusCode: 0)
        }

        return response
    }

    private func recordRequest(_ url: String) {
        requestedURLs.append(url)
    }

    private func getResponse(for url: String) -> HTTPResponse? {
        responses[url]
    }

    private func getError(for url: String) -> (any Error)? {
        errors[url]
    }
}
