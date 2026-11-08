# SwiftWebScraper Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

---

## Project Overview

### Mission
Fetch a public web page, extract structured data from it, and retrieve the site-level files beside it (`robots.txt`, sitemaps, `llms.txt`), with SSRF protection on every request. Extracted from geo-audit so the fetching core has one owner and one test suite.

### Target Users
- Swift services that audit or index other people's sites: geo-audit today; GeoSEOMCP and project-showcase are candidates.

### Key Differentiators
- Keeps the transport error when a fetch fails, instead of reporting an opaque status of 0.
- Takes an injectable `HTTPClientProtocol`, so callers choose the transport and tests need no network.
- Does not decide what a page means: the audit model stays with the caller.

---

## Architecture

### Technology Stack
- **Language:** Swift 6.2+
- **Build System:** Swift Package Manager
- **Testing:** Swift Testing framework
- **Concurrency:** Swift 6 strict concurrency throughout
- **Dependencies:** SwiftSoup (HTML parsing), swift-log

### Module Structure

```
Sources/SwiftWebScraper/
├── HTTPClient.swift          HTTPClientProtocol, HTTPResponse, URLSessionHTTPClient
├── URLValidator.swift        SSRF host check (string and resolving)
├── IPAddress.swift           parsed address + public/non-public classification
├── HostResolver.swift        HostResolver, SystemHostResolver (getaddrinfo)
├── RedirectFollower.swift    hop-by-hop redirect validation
├── HTMLExtractor.swift       page -> ExtractedHTML
├── ExtractedHTML.swift       ExtractedHTML, HeadingStructure, LinkSummary
├── SpecialFilesFetcher.swift robots.txt / sitemap.xml / llms.txt / ai.txt
├── SpecialFiles.swift        SpecialFiles
├── SitemapParser.swift       sitemap and sitemap-index parsing
├── JSONValue.swift           JSON-LD carrier type
└── ScraperError.swift
```

### Key Types

| Type | Purpose |
|------|---------|
| `HTTPClientProtocol` | The transport seam; inject your own |
| `URLValidator` | Rejects private, loopback and link-local hosts |
| `HTMLExtractor` | Turns HTML into `ExtractedHTML` |
| `SpecialFilesFetcher` | Fetches the site-level files beside a page |
| `ScraperError` | Failures, keeping the underlying cause |

### Data Flow

```
URL -> URLValidator -> HTTPClientProtocol.fetch -> HTMLExtractor -> ExtractedHTML
base URL -> SpecialFilesFetcher -> SpecialFiles
```

---

## Core Architectural Decisions

1. The audit model stays with the caller (decided 2026-11-07): this package returns what it found and does not interpret it.
2. `JSONValue` is owned here so the package needs no MCP client.
3. SSRF limits are documented rather than hidden; see the README and the design proposal.

---

## Current Status

### What's Working
- [x] Core extracted from geo-audit as 0.x (36 tests)

### What's Next
- [x] Resolve the SSRF gaps (DNS resolution, redirect re-validation, `fc`/`fd` hostname false positives) — shipped 0.2.0; DNS rebinding between check and connect remains and is documented
- [ ] Response size and timeout limits on the default client
- [ ] Reproduce and fix or replace the Linux `URLSession` client

---

## Quality Standards

### Code Quality
- All code follows `coding_rules.md`
- TDD: failing tests before implementation
- Documentation for all public APIs
- No warnings in build output
- Quality gate: 0 errors, 0 warnings before every commit

### Documentation Quality
- DocC comments for all public functions
- Usage examples in documentation
- Articles for complex topics

---

## Collaboration Principles

### AI as Sparring Partner, Not Oracle

AI proposes; the human interrogates. High AI confidence triggers harder questions, not faster acceptance.

- **Interrogate confident outputs.** When the AI states something with certainty, ask for the counterargument before accepting.
- **Demand counterarguments.** Before locking in an approach, require an explicit case for the strongest alternative.
- **Sit with discomfort.** Resist the pull to take the first plausible answer.

This principle is operationalized in the **Adversarial Review** step of `design_proposal.md`.

---

## Roadmap

### Phase 1: [Name]
- [ ] [Milestone]

### Phase 2: [Name]
- [ ] [Milestone]

### Future
- [Ideas not yet committed to]

---

**Last Updated:** 2026-11-08 (SSRF gaps fixed in 0.2.0; resolver, redirect follower and address classifier added)
