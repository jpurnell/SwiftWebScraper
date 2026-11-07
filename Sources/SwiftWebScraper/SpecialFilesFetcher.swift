import Foundation
import Logging

/// Fetches robots.txt, sitemap.xml, llms.txt, and referenced sitemaps from a domain.
public struct SpecialFilesFetcher: Sendable {
    private static let logger = Logger(label: "geo-audit.special-files")
    private let httpClient: HTTPClientProtocol

    /// Creates a new fetcher with the given HTTP client.
    public init(httpClient: HTTPClientProtocol = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    /// Fetch special files from the root domain.
    ///
    /// Missing files (404 or network error) return `nil` for that field rather than
    /// throwing. After fetching robots.txt, any `Sitemap:` directives are parsed
    /// and those URLs are fetched as well.
    ///
    /// - Parameter baseURL: The base URL of the site (e.g., `https://example.com`).
    /// - Returns: The fetched special files.
    public func fetch(baseURL: URL) async -> SpecialFiles {
        async let robotsResult = fetchOptionalFile(baseURL: baseURL, path: "/robots.txt")
        async let sitemapResult = fetchOptionalFile(baseURL: baseURL, path: "/sitemap.xml")
        async let llmsResult = fetchOptionalFile(baseURL: baseURL, path: "/llms.txt")
        async let aiResult = fetchOptionalFile(baseURL: baseURL, path: "/ai.txt")

        let robotsTxt = await robotsResult
        let sitemapXml = await sitemapResult
        let llmsTxt = await llmsResult
        let aiTxt = await aiResult

        // Parse Sitemap: directives from robots.txt and fetch referenced sitemaps
        let referencedSitemaps = await fetchReferencedSitemaps(from: robotsTxt)

        return SpecialFiles(
            robotsTxt: robotsTxt,
            sitemapXml: sitemapXml,
            llmsTxt: llmsTxt,
            aiTxt: aiTxt,
            referencedSitemaps: referencedSitemaps
        )
    }

    // MARK: - Private

    /// Fetch a file from the base URL, returning nil on 404 or error.
    private func fetchOptionalFile(baseURL: URL, path: String) async -> String? {
        guard let fileURL = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            return nil
        }

        do {
            let response = try await httpClient.fetch(url: fileURL)
            guard (200...299).contains(response.statusCode) else {
                return nil
            }
            return String(data: response.body, encoding: .utf8)
        } catch {
            Self.logger.debug("Failed to fetch special file — skipping", metadata: ["path": "\(path)", "error": "\(error)"])
            return nil
        }
    }

    /// Parse `Sitemap:` directives from robots.txt content and fetch each URL.
    private func fetchReferencedSitemaps(from robotsTxt: String?) async -> [String: String] {
        guard let robotsTxt = robotsTxt else { return [:] }

        let sitemapURLs = robotsTxt
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.lowercased().hasPrefix("sitemap:") else { return nil }
                return trimmed.dropFirst("Sitemap:".count).trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }

        var results: [String: String] = [:]

        await withTaskGroup(of: (String, String?).self) { group in
            for urlString in sitemapURLs {
                group.addTask {
                    guard let url = URL(string: urlString) else { return (urlString, nil) }
                    do {
                        let response = try await self.httpClient.fetch(url: url)
                        guard (200...299).contains(response.statusCode) else {
                            return (urlString, nil)
                        }
                        return (urlString, String(data: response.body, encoding: .utf8))
                    } catch {
                        Self.logger.debug("Failed to fetch referenced sitemap — skipping", metadata: ["url": "\(urlString)", "error": "\(error)"])
                        return (urlString, nil)
                    }
                }
            }

            for await (urlString, content) in group {
                if let content = content {
                    results[urlString] = content
                }
            }
        }

        return results
    }
}
