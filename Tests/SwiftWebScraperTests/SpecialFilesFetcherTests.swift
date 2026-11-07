import Testing
import Foundation
@testable import SwiftWebScraper

@Suite("SpecialFilesFetcher")
struct SpecialFilesFetcherTests {

    let baseURL: URL

    init() throws {
        baseURL = try #require(URL(string: "https://example.com"))
    }

    // MARK: - Golden Path

    @Test("Fetches all three special files when they exist")
    func fetchAllFiles() async {
        let client = MockHTTPClient()
        await client.register(url: "https://example.com/robots.txt", response: HTTPResponse(
            statusCode: 200, body: "User-agent: *\nDisallow: /private".data(using: .utf8) ?? Data()
        ))
        await client.register(url: "https://example.com/sitemap.xml", response: HTTPResponse(
            statusCode: 200, body: "<urlset></urlset>".data(using: .utf8) ?? Data()
        ))
        await client.register(url: "https://example.com/llms.txt", response: HTTPResponse(
            statusCode: 200, body: "# LLMs.txt\nAllow: all".data(using: .utf8) ?? Data()
        ))

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.robotsTxt == "User-agent: *\nDisallow: /private")
        #expect(result.sitemapXml == "<urlset></urlset>")
        #expect(result.llmsTxt == "# LLMs.txt\nAllow: all")
    }

    @Test("Returns nil for files that return 404")
    func fetch404Files() async {
        let client = MockHTTPClient()
        await client.register(url: "https://example.com/robots.txt", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/sitemap.xml", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/llms.txt", response: HTTPResponse(statusCode: 404))

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.robotsTxt == nil)
        #expect(result.sitemapXml == nil)
        #expect(result.llmsTxt == nil)
    }

    @Test("Mixed availability: some files exist, some don't")
    func fetchMixedAvailability() async {
        let client = MockHTTPClient()
        await client.register(url: "https://example.com/robots.txt", response: HTTPResponse(
            statusCode: 200, body: "User-agent: *".data(using: .utf8) ?? Data()
        ))
        await client.register(url: "https://example.com/sitemap.xml", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/llms.txt", response: HTTPResponse(statusCode: 404))

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.robotsTxt == "User-agent: *")
        #expect(result.sitemapXml == nil)
        #expect(result.llmsTxt == nil)
    }

    // MARK: - Referenced Sitemaps

    @Test("Fetches sitemaps referenced in robots.txt")
    func fetchReferencedSitemaps() async {
        let client = MockHTTPClient()
        let robotsTxt = "User-agent: *\nDisallow: /private\nSitemap: https://example.com/sitemap-posts.xml\nSitemap: https://example.com/sitemap-pages.xml"
        await client.register(url: "https://example.com/robots.txt", response: HTTPResponse(
            statusCode: 200, body: robotsTxt.data(using: .utf8) ?? Data()
        ))
        await client.register(url: "https://example.com/sitemap.xml", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/llms.txt", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/sitemap-posts.xml", response: HTTPResponse(
            statusCode: 200, body: "<urlset>posts</urlset>".data(using: .utf8) ?? Data()
        ))
        await client.register(url: "https://example.com/sitemap-pages.xml", response: HTTPResponse(
            statusCode: 200, body: "<urlset>pages</urlset>".data(using: .utf8) ?? Data()
        ))

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.referencedSitemaps.count == 2)
        #expect(result.referencedSitemaps["https://example.com/sitemap-posts.xml"] == "<urlset>posts</urlset>")
        #expect(result.referencedSitemaps["https://example.com/sitemap-pages.xml"] == "<urlset>pages</urlset>")
    }

    @Test("Fetches sitemaps from a robots.txt with CRLF line endings")
    func fetchReferencedSitemapsCRLF() async {
        let client = MockHTTPClient()
        let robotsTxt = "User-agent: *\r\nDisallow: /private\r\nSitemap: https://example.com/sitemap-posts.xml\r\nSitemap: https://example.com/sitemap-pages.xml\r\n"
        await client.register(url: "https://example.com/robots.txt", response: HTTPResponse(
            statusCode: 200, body: Data(robotsTxt.utf8)
        ))
        await client.register(url: "https://example.com/sitemap.xml", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/llms.txt", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/sitemap-posts.xml", response: HTTPResponse(
            statusCode: 200, body: Data("<urlset>posts</urlset>".utf8)
        ))
        await client.register(url: "https://example.com/sitemap-pages.xml", response: HTTPResponse(
            statusCode: 200, body: Data("<urlset>pages</urlset>".utf8)
        ))

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.referencedSitemaps.count == 2)
        #expect(result.referencedSitemaps["https://example.com/sitemap-posts.xml"] == "<urlset>posts</urlset>")
        #expect(result.referencedSitemaps["https://example.com/sitemap-pages.xml"] == "<urlset>pages</urlset>")
    }

    @Test("Referenced sitemap that returns 404 is excluded")
    func referencedSitemap404() async {
        let client = MockHTTPClient()
        let robotsTxt = "Sitemap: https://example.com/missing-sitemap.xml"
        await client.register(url: "https://example.com/robots.txt", response: HTTPResponse(
            statusCode: 200, body: robotsTxt.data(using: .utf8) ?? Data()
        ))
        await client.register(url: "https://example.com/sitemap.xml", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/llms.txt", response: HTTPResponse(statusCode: 404))
        // missing-sitemap.xml not registered — will throw

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.referencedSitemaps.isEmpty)
    }

    // MARK: - Error Resilience

    @Test("Network error for special file returns nil gracefully")
    func networkErrorReturnsNil() async {
        let client = MockHTTPClient()
        await client.register(url: "https://example.com/robots.txt", error: ScraperError.networkError(url: "https://example.com", underlying: "timed out"))
        await client.register(url: "https://example.com/sitemap.xml", error: ScraperError.networkError(url: "https://example.com", underlying: "timed out"))
        await client.register(url: "https://example.com/llms.txt", error: ScraperError.networkError(url: "https://example.com", underlying: "timed out"))

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.robotsTxt == nil)
        #expect(result.sitemapXml == nil)
        #expect(result.llmsTxt == nil)
    }

    @Test("No sitemaps referenced when robots.txt has no Sitemap directives")
    func noReferencedSitemaps() async {
        let client = MockHTTPClient()
        await client.register(url: "https://example.com/robots.txt", response: HTTPResponse(
            statusCode: 200, body: "User-agent: *\nDisallow: /".data(using: .utf8) ?? Data()
        ))
        await client.register(url: "https://example.com/sitemap.xml", response: HTTPResponse(statusCode: 404))
        await client.register(url: "https://example.com/llms.txt", response: HTTPResponse(statusCode: 404))

        let fetcher = SpecialFilesFetcher(httpClient: client)
        let result = await fetcher.fetch(baseURL: baseURL)

        #expect(result.referencedSitemaps.isEmpty)
    }
}
