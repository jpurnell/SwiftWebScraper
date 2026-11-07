# ``SwiftWebScraper``

Fetch a public web page and extract structured data from it, with SSRF protection.

## Overview

SwiftWebScraper is the fetching and extraction core. It does not decide what to do with a
page: it returns the page's metadata, headings, links and JSON-LD, plus the site-level files
that sit beside it (`robots.txt`, sitemaps, `llms.txt`). Callers compose these into whatever
model they need.

Every request made through ``URLSessionHTTPClient`` is checked by ``URLValidator`` first.
That check is on the hostname as written; see the limits listed in the project README.

## Topics

### Fetching

- ``HTTPClientProtocol``
- ``URLSessionHTTPClient``
- ``HTTPResponse``
- ``URLValidator``

### Extracting a page

- ``HTMLExtractor``
- ``ExtractedHTML``
- ``HeadingStructure``
- ``LinkSummary``
- ``JSONValue``

### Site-level files

- ``SpecialFilesFetcher``
- ``SpecialFiles``
- ``SitemapParser``

### Errors

- ``ScraperError``
