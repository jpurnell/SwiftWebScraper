import Foundation

/// Special files fetched from the root domain.
public struct SpecialFiles: Codable, Sendable, Equatable {
    /// Contents of `/robots.txt`, or nil if not found.
    public let robotsTxt: String?
    /// Contents of `/sitemap.xml`, or nil if not found.
    public let sitemapXml: String?
    /// Contents of `/llms.txt`, or nil if not found.
    public let llmsTxt: String?
    /// Contents of `/ai.txt`, or nil if not found.
    public let aiTxt: String?
    /// Sitemaps referenced in robots.txt, keyed by URL.
    public let referencedSitemaps: [String: String]

    /// Creates a new instance with the given special file contents.
    public init(
        robotsTxt: String? = nil,
        sitemapXml: String? = nil,
        llmsTxt: String? = nil,
        aiTxt: String? = nil,
        referencedSitemaps: [String: String] = [:]
    ) {
        self.robotsTxt = robotsTxt
        self.sitemapXml = sitemapXml
        self.llmsTxt = llmsTxt
        self.aiTxt = aiTxt
        self.referencedSitemaps = referencedSitemaps
    }
}
