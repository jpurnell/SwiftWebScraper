# Changelog

All notable changes to SwiftWebScraper are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-11-08

### Security
- Hostnames are now resolved and refused if any address they resolve to is private or reserved
  (`URLValidator.validateResolvingHost(of:using:)`, `HostResolver`, `SystemHostResolver`).
- Redirects are validated hop by hop (`RedirectFollower`); `URLSessionHTTPClient` no longer lets
  URLSession follow them unchecked.
- IP literals are classified by parsed address (`IPAddress`), covering decimal/hex/octal IPv4,
  IPv4-mapped, NAT64 and 6to4 IPv6, carrier-grade NAT, multicast and reserved ranges.
- Fixed `fc`/`fd` hostname false positives: `fcc.gov` and `fdic.gov` were being rejected.
- `*.localhost`, `*.local` and `*.internal` names are refused.

### Added
- `URLSessionHTTPClient(maxRedirects:timeout:)`; requests now time out after 30 seconds by default.
- Live-network tests (off unless `SWIFTWEBSCRAPER_LIVE` is set) and a Linux CI workflow.

### Known limits
- DNS rebinding between validation and connection is not closed; see the README.

## [0.1.0] - 2026-11-07

### Added
- Extracted from geo-audit's `WebScraper` target: `HTTPClientProtocol`, `URLSessionHTTPClient`,
  `URLValidator`, `HTMLExtractor`, `SpecialFilesFetcher`, `SitemapParser`, `ExtractedHTML`,
  `HeadingStructure`, `LinkSummary`, `SpecialFiles`, `ScraperError`.
- `JSONValue`, replacing the `AnyCodableValue` dependency on an MCP client.
- `ScraperError.networkError(url:underlying:)`, and `LocalizedError` conformance.
- Project scaffold from the development guidelines, and the extraction design proposal.

[Unreleased]: https://github.com/jpurnell/SwiftWebScraper/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/jpurnell/SwiftWebScraper/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jpurnell/SwiftWebScraper/releases/tag/v0.1.0
