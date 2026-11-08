# SwiftWebScraper

Fetches a public web page, extracts structured data from it, and retrieves the site-level
files beside it (`robots.txt`, sitemaps, `llms.txt`), with SSRF protection on every request.

**Status:** pre-release (`0.x`). Extracted from geo-audit's `WebScraper` target; see
[`project/plans/proposals/SwiftWebScraper-extraction.md`](project/plans/proposals/SwiftWebScraper-extraction.md).

## What it does

- `URLSessionHTTPClient` fetches a URL once `URLValidator` and `RedirectFollower` have vetted it and each redirect.
- `HTMLExtractor` returns title, meta tags, headings, links, word count and JSON-LD (`JSONValue`).
- `SpecialFilesFetcher` retrieves `robots.txt`, `sitemap.xml`, `llms.txt` and `ai.txt`, plus sitemaps that `robots.txt` references.
- `ScraperError.networkError` keeps the transport error, so a failed fetch says why.

## SSRF protection

`URLSessionHTTPClient` checks every request, and every redirect it is sent through, before connecting:

- The scheme must be `http` or `https`.
- IP literals are judged by address, in every spelling a resolver accepts (`2130706433`,
  `0x7f.0.0.1`, `127.1`, bracketed IPv6, IPv4-mapped and NAT64 forms). Loopback, private,
  link-local, carrier-grade NAT, documentation, multicast and reserved ranges are refused.
- Hostnames are **resolved**, and refused if any address they resolve to is non-public.
- Redirects are followed one hop at a time by `RedirectFollower`, each destination validated
  before it is requested, with a limit of 5.

`URLValidator.validatedURL(_:)` and `validatePublicURL(_:)` remain string-only checks with no DNS
lookup. They suit filtering a list of links; use `validateResolvingHost(of:using:)` before an
actual request.

**Not covered: DNS rebinding.** The check resolves the name, then the HTTP client resolves it again
when it connects. A resolver that answers differently the second time can still get a request
through. Closing that needs the client to connect to the address that was validated, which
`URLSession` does not allow. If your threat model includes a hostile DNS server, run the scraper
where private addresses are unreachable (network policy), as well as relying on this check.

A custom `HTTPClientProtocol` is not validated unless it calls `RedirectFollower.fetch` or
`URLValidator.validateResolvingHost` itself.

## Requirements

Swift 6.x, macOS or Linux.

## Known issue: `URLSessionHTTPClient` on Linux

geo-audit's production client (`NIOHTTPClient`, AsyncHTTPClient-based) documents that it replaced
`URLSessionHTTPClient` "to avoid FoundationNetworking/libcurl crashes on Linux". The default client
here is that `URLSession` one, so on Linux inject your own `HTTPClientProtocol` and call
`URLValidator.validatePublicURL` in it, as geo-audit does. Not yet reproduced in this package.
