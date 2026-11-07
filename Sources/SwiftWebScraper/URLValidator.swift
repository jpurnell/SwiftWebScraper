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
        // Localhost variants
        if host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]" {
            return true
        }

        // IPv4 loopback range 127.x.x.x
        if host.hasPrefix("127.") { return true }

        // IPv4 private ranges
        if host.hasPrefix("10.") { return true }
        if host.hasPrefix("192.168.") { return true }
        if host.hasPrefix("172.") {
            let octets = host.split(separator: ".")
            if octets.count >= 2, let second = Int(octets[1]), (16...31).contains(second) {
                return true
            }
        }

        // Unspecified address
        if host == "0.0.0.0" || host.hasPrefix("0.") { return true }

        // Link-local
        if host.hasPrefix("169.254.") { return true }
        if host.hasPrefix("fe80:") || host.hasPrefix("[fe80:") { return true }

        // Cloud metadata endpoints
        if host == "metadata.google.internal" { return true }

        // IPv6 unique local (fc00::/7)
        if host.hasPrefix("fc") || host.hasPrefix("fd") { return true }
        if host.hasPrefix("[fc") || host.hasPrefix("[fd") { return true }

        return false
    }
}
