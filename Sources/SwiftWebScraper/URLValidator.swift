import Foundation

/// Validates URLs are safe for server-side HTTP requests.
///
/// Prevents SSRF by rejecting private IPs, localhost, link-local addresses,
/// cloud metadata endpoints, and non-HTTP schemes.
public enum URLValidator {

    /// Parses a URL string and validates it is safe for outbound HTTP requests.
    ///
    /// - Parameter string: The URL string to parse and validate.
    /// - Returns: A validated URL, or `nil` if the string is not a valid public URL.
    public static func validatedURL(_ string: String) -> URL? {
        guard let url = URL(string: string) else { return nil }
        guard rejection(for: url) == nil else { return nil }
        return url
    }

    /// Validates a URL is safe for outbound HTTP requests.
    ///
    /// - Parameter url: The URL to validate.
    /// - Throws: ``ScraperError/unsafeURL(_:reason:)`` if the URL targets a private or restricted address.
    public static func validatePublicURL(_ url: URL) throws {
        if let rejection = rejection(for: url) {
            throw rejection
        }
    }

    /// Validates a URL and checks that its hostname does not resolve to a non-public address.
    ///
    /// Runs every check ``validatePublicURL(_:)`` does, then resolves the host and rejects the URL
    /// if *any* address it resolves to is private or reserved. This is what stops a public-looking
    /// name that points at `10.0.0.5` or `169.254.169.254`.
    ///
    /// This is a check, not a connection pin: the HTTP client resolves the name again when it
    /// connects, so a resolver that answers differently the second time (DNS rebinding) can still
    /// get through. See the README's security notes.
    ///
    /// - Parameters:
    ///   - url: The URL to validate.
    ///   - resolver: How to resolve the host. Defaults to the system resolver.
    /// - Throws: ``ScraperError/unsafeURL(_:reason:)`` if the URL or any resolved address is unsafe,
    ///   or ``ScraperError/networkError(url:underlying:)`` if the host does not resolve.
    public static func validateResolvingHost(
        of url: URL,
        using resolver: any HostResolver = SystemHostResolver()
    ) async throws {
        try validatePublicURL(url)
        guard let host = url.host?.lowercased(), IPAddress.parse(host) == nil else { return }

        let addresses = try await resolver.resolve(host)
        guard !addresses.isEmpty else {
            throw ScraperError.networkError(url: url.absoluteString, underlying: "DNS resolution returned no addresses")
        }
        if addresses.contains(where: { !$0.isPublic }) {
            throw ScraperError.unsafeURL(url.absoluteString, reason: "Host resolves to a private or reserved address")
        }
    }

    // MARK: - Private

    private static func rejection(for url: URL) -> ScraperError? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .unsafeURL(url.absoluteString, reason: "Only http and https schemes are allowed")
        }

        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return .unsafeURL(url.absoluteString, reason: "URL must have a host")
        }

        if isRestricted(host) {
            return .unsafeURL(url.absoluteString, reason: "Requests to private or reserved addresses are not allowed")
        }
        return nil
    }

    private static func isRestricted(_ host: String) -> Bool {
        // IP literals, including legacy spellings (decimal, hex, octal) of IPv4, are judged by address.
        if let address = IPAddress.parse(host) {
            return !address.isPublic
        }

        // Names that never name a public host.
        if host == "localhost" || host.hasSuffix(".localhost") { return true }
        if host.hasSuffix(".local") || host.hasSuffix(".internal") { return true }
        if host.contains("%") { return true }
        return false
    }
}
