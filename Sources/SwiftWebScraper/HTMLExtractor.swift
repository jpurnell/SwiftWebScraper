import Foundation
import Logging
import SwiftSoup

/// Extracts structured metadata from raw HTML using SwiftSoup.
public struct HTMLExtractor: Sendable {
    private static let logger = Logger(label: "swift-web-scraper.html-extractor")

    /// Runs one SwiftSoup query. A throw is logged at debug level and reads as "absent",
    /// because a page missing an element is ordinary and must not fail the whole extraction.
    private static func query<T>(_ step: String, _ body: () throws -> T?) -> T? {
        do {
            return try body()
        } catch {
            logger.debug("HTML extraction step failed — treating as absent", metadata: ["step": "\(step)", "error": "\(error)"])
            return nil
        }
    }

    /// Extract metadata from raw HTML string.
    ///
    /// - Parameters:
    ///   - html: The raw HTML string to parse.
    ///   - baseURL: The base URL of the page (used for resolving relative links).
    /// - Returns: Extracted metadata and structure.
    /// - Throws: ``ScraperError/parseError(reason:)`` if HTML cannot be parsed.
    public static func extract(from html: String, baseURL: URL) throws -> ExtractedHTML {
        let document: Document
        do {
            document = try SwiftSoup.parse(html, baseURL.absoluteString)
        } catch {
            throw ScraperError.parseError(reason: error.localizedDescription)
        }

        let title = query("title") { try document.title().nilIfEmpty }
        let metaDescription = query("metaDescription") { try document.select("meta[name=description]").first()?.attr("content").nilIfEmpty }
        let metaKeywords = query("metaKeywords") { try document.select("meta[name=keywords]").first()?.attr("content").nilIfEmpty }
        let canonicalURL = query("canonicalURL") { try document.select("link[rel=canonical]").first()?.attr("href").nilIfEmpty }

        let ogTags = extractOGTags(from: document)
        let headings = extractHeadings(from: document)
        let jsonLD = extractJSONLD(from: document)
        let bodyText = extractBodyText(from: document)
        let wordCount = countWords(in: bodyText)
        let links = extractLinks(from: document, baseURL: baseURL)

        return ExtractedHTML(
            title: title,
            metaDescription: metaDescription,
            metaKeywords: metaKeywords,
            canonicalURL: canonicalURL,
            ogTags: ogTags,
            headings: headings,
            jsonLD: jsonLD,
            wordCount: wordCount,
            bodyText: bodyText,
            links: links
        )
    }

    // MARK: - Private Extraction Methods

    private static func extractOGTags(from document: Document) -> [String: String] {
        var tags: [String: String] = [:]
        guard let elements = query("og tags", { try document.select("meta[property^=og:]") }) else { return tags }
        for element in elements {
            if let property = query("og property", { try element.attr("property") }),
               let content = query("og content", { try element.attr("content") }),
               !property.isEmpty, !content.isEmpty {
                tags[property] = content
            }
        }
        return tags
    }

    private static func extractHeadings(from document: Document) -> HeadingStructure {
        func headingTexts(_ tag: String) -> [String] {
            guard let elements = query("headings \(tag)", { try document.select(tag) }) else { return [] }
            return elements.compactMap { element in query("heading text", { try element.text() }) }.filter { !$0.isEmpty }
        }

        return HeadingStructure(
            h1: headingTexts("h1"),
            h2: headingTexts("h2"),
            h3: headingTexts("h3"),
            h4: headingTexts("h4"),
            h5: headingTexts("h5"),
            h6: headingTexts("h6")
        )
    }

    private static func extractJSONLD(from document: Document) -> [JSONValue] {
        guard let scripts = query("json-ld scripts", { try document.select("script[type=application/ld+json]") }) else { return [] }
        var results: [JSONValue] = []
        for script in scripts {
            guard let jsonString = Optional(script.data()),
                  let data = jsonString.data(using: .utf8) else { continue }
            do {
                results.append(try JSONDecoder().decode(JSONValue.self, from: data))
            } catch {
                Self.logger.debug("Skipping malformed JSON-LD block", metadata: ["error": "\(error)"])
            }
        }
        return results
    }

    private static func extractBodyText(from document: Document) -> String {
        guard let body = document.body(),
              let text = query("body text", { try body.text() }) else { return "" }
        return text
    }

    private static func countWords(in text: String) -> Int {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return words.count
    }

    private static func extractLinks(from document: Document, baseURL: URL) -> LinkSummary {
        guard let anchors = query("anchors", { try document.select("a[href]") }) else {
            return LinkSummary()
        }

        var internalCount = 0
        var externalCount = 0
        var nofollowCount = 0
        var externalURLs: [String] = []
        var internalURLSet: Set<String> = []
        let baseHost = baseURL.host ?? ""

        for anchor in anchors {
            guard let href = query("href", { try anchor.attr("href") }), !href.isEmpty else { continue }

            let isNofollow = query("rel", { try anchor.attr("rel") })?.contains("nofollow") ?? false
            if isNofollow {
                nofollowCount += 1
            }

            // Determine if internal or external
            if href.hasPrefix("#") {
                internalCount += 1
            } else if href.hasPrefix("/") {
                internalCount += 1
                // Resolve to absolute URL for subpage crawling
                if let resolved = URL(string: href, relativeTo: baseURL)?.absoluteString {
                    internalURLSet.insert(resolved)
                }
            } else if let linkURL = URL(string: href),
                      let linkHost = linkURL.host {
                if linkHost == baseHost || linkHost.hasSuffix(".\(baseHost)") {
                    internalCount += 1
                    internalURLSet.insert(linkURL.absoluteString)
                } else {
                    externalCount += 1
                    externalURLs.append(href)
                }
            } else {
                internalCount += 1 // relative URLs without leading slash
                if let resolved = URL(string: href, relativeTo: baseURL)?.absoluteString {
                    internalURLSet.insert(resolved)
                }
            }
        }

        return LinkSummary(
            internalCount: internalCount,
            externalCount: externalCount,
            nofollowCount: nofollowCount,
            externalURLs: externalURLs,
            internalURLs: Array(internalURLSet)
        )
    }
}

// MARK: - String Extension

private extension String {
    /// Returns nil if the string is empty, otherwise returns self.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
