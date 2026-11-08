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
///
/// Every request, and every redirect it is sent through, is validated with
/// ``URLValidator/validateResolvingHost(of:using:)`` before it is made. URLSession's own redirect
/// handling is switched off so ``RedirectFollower`` can do that checking.
public struct URLSessionHTTPClient: HTTPClientProtocol, Sendable {
    private let maxRedirects: Int
    private let timeout: TimeInterval

    /// Creates a new URLSession-based HTTP client.
    ///
    /// - Parameters:
    ///   - maxRedirects: The most redirects to follow. Default 5.
    ///   - timeout: Per-request timeout in seconds. Default 30.
    public init(maxRedirects: Int = 5, timeout: TimeInterval = 30) {
        self.maxRedirects = maxRedirects
        self.timeout = timeout
    }

    /// Fetch the contents of the given URL via URLSession, following only safe redirects.
    public func fetch(url: URL) async throws -> HTTPResponse {
        let timeout = self.timeout
        return try await RedirectFollower.fetch(url, maxRedirects: maxRedirects) { hop in
            try await Self.singleRequest(to: hop, timeout: timeout)
        }
    }

    private static func singleRequest(to url: URL, timeout: TimeInterval) async throws -> HTTPResponse {
        let session = URLSession(configuration: .ephemeral, delegate: RedirectRefuser(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)

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

/// Answers every redirect with "do not follow", so the 3xx response comes back to the caller.
private final class RedirectRefuser: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
