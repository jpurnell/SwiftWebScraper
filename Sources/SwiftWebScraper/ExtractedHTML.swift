import Foundation

/// Extracted metadata and structure from an HTML page.
public struct ExtractedHTML: Codable, Sendable, Equatable {
    /// The page title from the `<title>` tag.
    public let title: String?
    /// Content of the `<meta name="description">` tag.
    public let metaDescription: String?
    /// Content of the `<meta name="keywords">` tag.
    public let metaKeywords: String?
    /// Canonical URL from the `<link rel="canonical">` tag.
    public let canonicalURL: String?
    /// Open Graph meta tags keyed by property name.
    public let ogTags: [String: String]
    /// Heading structure (h1 through h6) extracted from the page.
    public let headings: HeadingStructure
    /// JSON-LD structured data blocks found on the page.
    public let jsonLD: [JSONValue]
    /// Total word count of the page body text.
    public let wordCount: Int
    /// Plain text content extracted from the page body.
    public let bodyText: String
    /// Summary of internal, external, and nofollow links.
    public let links: LinkSummary

    /// Creates a new instance with the given extracted HTML data.
    public init(
        title: String? = nil,
        metaDescription: String? = nil,
        metaKeywords: String? = nil,
        canonicalURL: String? = nil,
        ogTags: [String: String] = [:],
        headings: HeadingStructure = HeadingStructure(),
        jsonLD: [JSONValue] = [],
        wordCount: Int = 0,
        bodyText: String = "",
        links: LinkSummary = LinkSummary()
    ) {
        self.title = title
        self.metaDescription = metaDescription
        self.metaKeywords = metaKeywords
        self.canonicalURL = canonicalURL
        self.ogTags = ogTags
        self.headings = headings
        self.jsonLD = jsonLD
        self.wordCount = wordCount
        self.bodyText = bodyText
        self.links = links
    }
}

/// Heading structure extracted from an HTML page.
public struct HeadingStructure: Codable, Sendable, Equatable {
    /// All `<h1>` heading texts.
    public let h1: [String]
    /// All `<h2>` heading texts.
    public let h2: [String]
    /// All `<h3>` heading texts.
    public let h3: [String]
    /// All `<h4>` heading texts.
    public let h4: [String]
    /// All `<h5>` heading texts.
    public let h5: [String]
    /// All `<h6>` heading texts.
    public let h6: [String]

    /// Creates a new instance with the given heading arrays.
    public init(
        h1: [String] = [],
        h2: [String] = [],
        h3: [String] = [],
        h4: [String] = [],
        h5: [String] = [],
        h6: [String] = []
    ) {
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
        self.h4 = h4
        self.h5 = h5
        self.h6 = h6
    }
}

/// Summary of link counts on a page.
public struct LinkSummary: Codable, Sendable, Equatable {
    /// Number of internal links on the page.
    public let internalCount: Int
    /// Number of external links on the page.
    public let externalCount: Int
    /// Number of nofollow links on the page.
    public let nofollowCount: Int
    /// External link URLs (deduplicated, lowercased hosts).
    public let externalURLs: [String]
    /// Internal link URLs (deduplicated, resolved to absolute paths).
    public let internalURLs: [String]

    /// Creates a new instance with the given link counts and URL lists.
    public init(internalCount: Int = 0, externalCount: Int = 0, nofollowCount: Int = 0, externalURLs: [String] = [], internalURLs: [String] = []) {
        self.internalCount = internalCount
        self.externalCount = externalCount
        self.nofollowCount = nofollowCount
        self.externalURLs = externalURLs
        self.internalURLs = internalURLs
    }
}
