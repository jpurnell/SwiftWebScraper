import Foundation

/// Errors that can occur during web scraping operations.
public enum ScraperError: Error, Sendable, Equatable {
    /// HTTP fetch returned a non-success status code.
    case fetchFailed(url: String, statusCode: Int)

    /// The request failed before any HTTP response arrived (DNS, connection, TLS).
    ///
    /// `underlying` is the transport error's description, kept so callers can log the real cause.
    case networkError(url: String, underlying: String)

    /// HTML parsing or extraction failed.
    case parseError(reason: String)

    /// The URL targets a private, reserved, or otherwise unsafe address.
    case unsafeURL(String, reason: String)
}

extension ScraperError: LocalizedError {
    /// A human-readable message naming the URL and cause, used by `localizedDescription`.
    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let url, let statusCode):
            return "Fetching \(url) failed with status \(statusCode)"
        case .networkError(let url, let underlying):
            return "Could not reach \(url): \(underlying)"
        case .parseError(let reason):
            return "Could not parse the page: \(reason)"
        case .unsafeURL(let url, let reason):
            return "Refused to fetch \(url): \(reason)"
        }
    }
}
