import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An HTTP response containing status code, headers, and body data.
public struct HTTPResponse: Sendable, Equatable {
    /// HTTP status code from the server response.
    public let statusCode: Int
    /// HTTP response headers keyed by header name.
    public let headers: [String: String]
    /// Raw response body data.
    public let body: Data

    /// Creates a new instance with the given status code, headers, and body.
    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

/// Protocol for HTTP client operations, enabling testability with mock implementations.
public protocol HTTPClientProtocol: Sendable {
    func fetch(url: URL) async throws -> HTTPResponse
}

/// Default HTTP client using URLSession.
public struct URLSessionHTTPClient: HTTPClientProtocol, Sendable {
    /// Creates a new URLSession-based HTTP client.
    public init() {}

    /// Fetch the contents of the given URL via URLSession.
    public func fetch(url: URL) async throws -> HTTPResponse {
        try URLValidator.validatePublicURL(url)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScraperError.fetchFailed(url: url.absoluteString, statusCode: 0)
        }

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyStr = key as? String, let valStr = value as? String {
                headers[keyStr] = valStr
            }
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data
        )
    }
}
