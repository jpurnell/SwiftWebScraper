# SwiftWebScraper

Fetches a public web page, extracts structured data from it, and retrieves the site-level
files beside it (`robots.txt`, sitemaps, `llms.txt`), with SSRF protection on every request.

**Status:** pre-release (`0.x`). Extracted from geo-audit's `WebScraper` target; see
[`project/plans/proposals/SwiftWebScraper-extraction.md`](project/plans/proposals/SwiftWebScraper-extraction.md).

## What it does

- `URLSessionHTTPClient` fetches a URL after `URLValidator` rejects private, loopback and link-local hosts.
- `HTMLExtractor` returns title, meta tags, headings, links, word count and JSON-LD (`JSONValue`).
- `SpecialFilesFetcher` retrieves `robots.txt`, `sitemap.xml`, `llms.txt` and `ai.txt`, plus sitemaps that `robots.txt` references.
- `ScraperError.networkError` keeps the transport error, so a failed fetch says why.

## Known limits of the SSRF check

`URLValidator` inspects the hostname **as written**. It does not resolve DNS, so a public name that
resolves to a private address passes, and it does not re-check redirect targets. Its `fc`/`fd`
prefix test for IPv6 unique-local addresses also matches hostnames such as `fcc.gov`. These came
across unchanged from geo-audit and are tracked in the design proposal (section 6).

## Requirements

Swift 6.x, macOS or Linux.

## Known issue: `URLSessionHTTPClient` on Linux

geo-audit's production client (`NIOHTTPClient`, AsyncHTTPClient-based) documents that it replaced
`URLSessionHTTPClient` "to avoid FoundationNetworking/libcurl crashes on Linux". The default client
here is that `URLSession` one, so on Linux inject your own `HTTPClientProtocol` and call
`URLValidator.validatePublicURL` in it, as geo-audit does. Not yet reproduced in this package.
