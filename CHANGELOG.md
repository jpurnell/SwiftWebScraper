# Changelog

All notable changes to SwiftWebScraper are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Extracted from geo-audit's `WebScraper` target: `HTTPClientProtocol`, `URLSessionHTTPClient`,
  `URLValidator`, `HTMLExtractor`, `SpecialFilesFetcher`, `SitemapParser`, `ExtractedHTML`,
  `HeadingStructure`, `LinkSummary`, `SpecialFiles`, `ScraperError`.
- `JSONValue`, replacing the `AnyCodableValue` dependency on an MCP client.
- `ScraperError.networkError(url:underlying:)`, and `LocalizedError` conformance.
- Project scaffold from the development guidelines, and the extraction design proposal.
