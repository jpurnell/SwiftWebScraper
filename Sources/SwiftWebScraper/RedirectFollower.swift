import Foundation

/// Follows HTTP redirects one hop at a time, validating every destination before requesting it.
///
/// HTTP clients that follow redirects themselves only see the URL they were given, so a public
/// page can answer `302 Location: http://169.254.169.254/` and walk the request into the private
/// network. `RedirectFollower` takes that decision back: the client performs a single request with
/// automatic redirects turned off, and this type validates and follows each `Location` itself.
public enum RedirectFollower {

    /// Fetches a URL, following redirects only to destinations that pass validation.
    ///
    /// - Parameters:
    ///   - url: The starting URL. It is validated before the first request.
    ///   - maxRedirects: The most redirects to follow. Default 5.
    ///   - resolver: Resolves hostnames for ``URLValidator/validateResolvingHost(of:using:)``.
    ///   - hop: Performs one request and returns its response **without following redirects**.
    /// - Returns: The first response that is not a followable redirect.
    /// - Throws: ``ScraperError/unsafeURL(_:reason:)`` if the start or any redirect target is unsafe;
    ///   ``ScraperError/networkError(url:underlying:)`` if the redirect limit is exceeded.
    public static func fetch(
        _ url: URL,
        maxRedirects: Int = 5,
        resolver: any HostResolver = SystemHostResolver(),
        hop: @Sendable (URL) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        var current = url
        for redirectsFollowed in 0...maxRedirects {
            try await URLValidator.validateResolvingHost(of: current, using: resolver)
            let response = try await hop(current)

            guard (300...399).contains(response.statusCode),
                  let location = Self.location(in: response),
                  let next = URL(string: location, relativeTo: current)?.absoluteURL else {
                return response
            }
            if redirectsFollowed == maxRedirects {
                throw ScraperError.networkError(
                    url: url.absoluteString,
                    underlying: "Too many redirects (limit \\(maxRedirects))"
                )
            }
            current = next
        }
        throw ScraperError.networkError(url: url.absoluteString, underlying: "Too many redirects (limit \\(maxRedirects))")
    }

    private static func location(in response: HTTPResponse) -> String? {
        response.headers.first { $0.key.lowercased() == "location" }?.value
    }
}
