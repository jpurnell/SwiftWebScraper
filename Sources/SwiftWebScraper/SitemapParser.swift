//
//  SitemapParser.swift
//  WebScraper
//
//  Parses sitemap XML to extract page URLs.
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Extracts page URLs from sitemap XML content.
///
/// Handles both regular sitemaps (`<urlset>`) and sitemap index files
/// (`<sitemapindex>`) per the sitemaps.org protocol.
public struct SitemapParser: Sendable {

    /// Parse page URLs from a `<urlset>` sitemap.
    /// - Parameter xml: Raw XML string of a sitemap.
    /// - Returns: Array of page URLs found in `<loc>` elements.
    public static func parseURLs(from xml: String) -> [URL] {
        let delegate = SitemapXMLDelegate(targetElement: "url")
        parse(xml: xml, delegate: delegate)
        return delegate.urls
    }

    /// Parse sub-sitemap URLs from a `<sitemapindex>`.
    /// - Parameter xml: Raw XML string of a sitemap index.
    /// - Returns: Array of sub-sitemap URLs found in `<loc>` elements.
    public static func parseSitemapIndexURLs(from xml: String) -> [URL] {
        let delegate = SitemapXMLDelegate(targetElement: "sitemap")
        parse(xml: xml, delegate: delegate)
        return delegate.urls
    }

    /// Aggregate all page URLs from a site's sitemaps.
    ///
    /// Combines URLs from the primary sitemap and any referenced sitemaps
    /// (discovered via `Sitemap:` directives in robots.txt). Deduplicates,
    /// filters to same-host, and excludes common asset paths.
    ///
    /// - Parameters:
    ///   - primarySitemap: Content of `/sitemap.xml`, if available.
    ///   - referencedSitemaps: Map of sitemap URL → XML content.
    ///   - baseHost: The target site's hostname for filtering.
    /// - Returns: Deduplicated, sorted array of page URLs.
    public static func allPageURLs(
        primarySitemap: String?,
        referencedSitemaps: [String: String],
        baseHost: String
    ) -> [URL] {
        var allURLs: Set<URL> = []

        // Parse primary sitemap (could be urlset or sitemapindex)
        if let xml = primarySitemap {
            let pageURLs = parseURLs(from: xml)
            if pageURLs.isEmpty {
                // Might be a sitemap index — parse sub-sitemaps
                let subSitemapURLs = parseSitemapIndexURLs(from: xml)
                for subURL in subSitemapURLs {
                    if let content = referencedSitemaps[subURL.absoluteString] {
                        allURLs.formUnion(parseURLs(from: content))
                    }
                }
            } else {
                allURLs.formUnion(pageURLs)
            }
        }

        // Parse all referenced sitemaps
        for (_, content) in referencedSitemaps {
            allURLs.formUnion(parseURLs(from: content))
        }

        // Filter to same host and exclude assets
        let filtered = allURLs.filter { url in
            guard let host = url.host else { return false }
            guard host == baseHost || host.hasSuffix(".\(baseHost)") else { return false }
            return !isAssetPath(url.path)
        }

        return filtered.sorted { $0.path < $1.path }
    }

    // MARK: - Private

    private static func parse(xml: String, delegate: SitemapXMLDelegate) {
        guard let data = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
    }

    private static let assetExtensions: Set<String> = [
        "css", "js", "png", "jpg", "jpeg", "gif", "svg", "ico",
        "pdf", "xml", "rss", "json", "txt", "woff", "woff2",
        "ttf", "eot", "mp3", "mp4", "zip", "webp", "avif"
    ]

    private static let assetPrefixes: [String] = [
        "/css/", "/js/", "/fonts/", "/images/", "/assets/",
        "/feed", "/tags/", "/tag/", "/wp-content/uploads/"
    ]

    private static func isAssetPath(_ path: String) -> Bool {
        let lowered = path.lowercased()

        // Check file extension
        if let dot = lowered.lastIndex(of: ".") {
            let ext = String(lowered[lowered.index(after: dot)...])
            if assetExtensions.contains(ext) { return true }
        }

        // Check directory prefixes
        for prefix in assetPrefixes {
            if lowered.hasPrefix(prefix) { return true }
        }

        return false
    }
}

// MARK: - XMLParser Delegate

/// NSXMLParser delegate that collects `<loc>` URLs from sitemap elements.
private final class SitemapXMLDelegate: NSObject, XMLParserDelegate {
    /// The parent element to look for ("url" or "sitemap").
    let targetElement: String

    /// Collected URLs.
    private(set) var urls: [URL] = []

    private var inTarget = false
    private var inLoc = false
    private var currentText = ""

    init(targetElement: String) {
        self.targetElement = targetElement
        super.init()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        if name == targetElement {
            inTarget = true
        } else if name == "loc" && inTarget {
            inLoc = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inLoc {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let name = elementName.lowercased()
        if name == "loc" && inLoc {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed) {
                urls.append(url)
            }
            inLoc = false
        } else if name == targetElement {
            inTarget = false
        }
    }
}
