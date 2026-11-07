import Testing
import Foundation
@testable import SwiftWebScraper

@Suite("HTMLExtractor")
struct HTMLExtractorTests {

    let baseURL: URL

    init() throws {
        baseURL = try #require(URL(string: "https://example.com"))
    }

    // MARK: - Golden Path

    @Test("Extracts title from HTML")
    func extractTitle() throws {
        let html = "<html><head><title>My Website</title></head><body></body></html>"
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.title == "My Website")
    }

    @Test("Extracts meta description")
    func extractMetaDescription() throws {
        let html = """
        <html><head>
            <meta name="description" content="A great website about things">
        </head><body></body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.metaDescription == "A great website about things")
    }

    @Test("Extracts meta keywords")
    func extractMetaKeywords() throws {
        let html = """
        <html><head>
            <meta name="keywords" content="swift, vapor, mcp">
        </head><body></body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.metaKeywords == "swift, vapor, mcp")
    }

    @Test("Extracts canonical URL")
    func extractCanonicalURL() throws {
        let html = """
        <html><head>
            <link rel="canonical" href="https://example.com/page">
        </head><body></body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.canonicalURL == "https://example.com/page")
    }

    @Test("Extracts Open Graph tags")
    func extractOGTags() throws {
        let html = """
        <html><head>
            <meta property="og:title" content="OG Title">
            <meta property="og:description" content="OG Desc">
            <meta property="og:image" content="https://example.com/img.png">
        </head><body></body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.ogTags["og:title"] == "OG Title")
        #expect(result.ogTags["og:description"] == "OG Desc")
        #expect(result.ogTags["og:image"] == "https://example.com/img.png")
    }

    @Test("Extracts heading structure")
    func extractHeadings() throws {
        let html = """
        <html><body>
            <h1>Main Title</h1>
            <h2>Section One</h2>
            <h2>Section Two</h2>
            <h3>Subsection</h3>
        </body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.headings.h1 == ["Main Title"])
        #expect(result.headings.h2 == ["Section One", "Section Two"])
        #expect(result.headings.h3 == ["Subsection"])
        #expect(result.headings.h4.isEmpty)
    }

    @Test("Extracts JSON-LD from script tags")
    func extractJSONLD() throws {
        let html = """
        <html><head>
            <script type="application/ld+json">{"@type":"Person","name":"John"}</script>
        </head><body></body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.jsonLD.count == 1)
        if case .object(let obj) = result.jsonLD.first {
            #expect(obj["@type"] == .string("Person"))
            #expect(obj["name"] == .string("John"))
        } else {
            Issue.record("Expected JSON-LD object")
        }
    }

    @Test("Counts words in body text")
    func countWords() throws {
        let html = """
        <html><body>
            <p>This is a simple paragraph with eight words total.</p>
        </body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.wordCount == 9)
    }

    @Test("Counts internal and external links")
    func countLinks() throws {
        let html = """
        <html><body>
            <a href="/about">About</a>
            <a href="https://example.com/contact">Contact</a>
            <a href="https://other.com">External</a>
            <a href="https://another.com" rel="nofollow">Nofollow</a>
        </body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.links.internalCount == 2)
        #expect(result.links.externalCount == 2)
        #expect(result.links.nofollowCount == 1)
    }

    @Test("Extracts full page with all fields")
    func extractFullPage() throws {
        let html = """
        <html><head>
            <title>Full Page Test</title>
            <meta name="description" content="A complete page">
            <meta name="keywords" content="test, full">
            <link rel="canonical" href="https://example.com/full">
            <meta property="og:title" content="OG Full">
            <script type="application/ld+json">{"@type":"WebSite","name":"Test"}</script>
        </head><body>
            <h1>Welcome</h1>
            <h2>About</h2>
            <p>This is the content of the page with several words.</p>
            <a href="/internal">Internal Link</a>
            <a href="https://external.com">External Link</a>
        </body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.title == "Full Page Test")
        #expect(result.metaDescription == "A complete page")
        #expect(result.metaKeywords == "test, full")
        #expect(result.canonicalURL == "https://example.com/full")
        #expect(result.ogTags["og:title"] == "OG Full")
        #expect(result.headings.h1 == ["Welcome"])
        #expect(result.headings.h2 == ["About"])
        #expect(result.jsonLD.count == 1)
        #expect(result.wordCount > 0)
        #expect(result.links.internalCount == 1)
        #expect(result.links.externalCount == 1)
    }

    // MARK: - Edge Cases

    @Test("Returns nil for missing title")
    func missingTitle() throws {
        let html = "<html><head></head><body></body></html>"
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.title == nil)
    }

    @Test("Returns nil for missing meta description")
    func missingMetaDescription() throws {
        let html = "<html><head></head><body></body></html>"
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.metaDescription == nil)
    }

    @Test("Handles multiple H1 tags")
    func multipleH1s() throws {
        let html = "<html><body><h1>First</h1><h1>Second</h1></body></html>"
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.headings.h1 == ["First", "Second"])
    }

    @Test("Handles multiple JSON-LD blocks")
    func multipleJSONLD() throws {
        let html = """
        <html><head>
            <script type="application/ld+json">{"@type":"Person"}</script>
            <script type="application/ld+json">{"@type":"Organization"}</script>
        </head><body></body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.jsonLD.count == 2)
    }

    @Test("Skips malformed JSON-LD gracefully")
    func malformedJSONLD() throws {
        let html = """
        <html><head>
            <script type="application/ld+json">{invalid json}</script>
            <script type="application/ld+json">{"@type":"Valid"}</script>
        </head><body></body></html>
        """
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.jsonLD.count == 1)
    }

    @Test("Empty body gives zero word count")
    func emptyBodyWordCount() throws {
        let html = "<html><body></body></html>"
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.wordCount == 0)
    }

    @Test("No links gives zero counts")
    func noLinks() throws {
        let html = "<html><body><p>No links here</p></body></html>"
        let result = try HTMLExtractor.extract(from: html, baseURL: baseURL)
        #expect(result.links.internalCount == 0)
        #expect(result.links.externalCount == 0)
        #expect(result.links.nofollowCount == 0)
    }

    // MARK: - Invalid Input

    @Test("Empty string returns default values")
    func emptyString() throws {
        let result = try HTMLExtractor.extract(from: "", baseURL: baseURL)
        #expect(result.title == nil)
        #expect(result.wordCount == 0)
    }

    @Test("Non-HTML content is handled gracefully")
    func nonHTMLContent() throws {
        let result = try HTMLExtractor.extract(from: "Just plain text content", baseURL: baseURL)
        #expect(result.title == nil)
        #expect(result.wordCount > 0)
    }
}
