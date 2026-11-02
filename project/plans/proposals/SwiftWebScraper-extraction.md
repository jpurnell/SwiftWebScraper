# Design Proposal: Extract `WebScraper` from geo-audit into `SwiftWebScraper`

**Status:** Draft — awaiting review
**Author:** Justin Purnell / Claude
**Date:** 2026-11-02
**Source:** `geo-audit/Sources/WebScraper` (1,191 lines, 11 files, own test target)

> Written under a usage limit. Sections 1–4, 10, 14 and 16 are complete; the rest
> carry a first pass and are marked **(first pass)** where they need a second look
> before approval.

---

## 1. Objective

Turn geo-audit's `WebScraper` target into a standalone, reusable Swift package that
fetches a public web page, extracts structured data from it, and retrieves the
site-level files that sit next to it (`robots.txt`, sitemaps, `llms.txt`) — with SSRF
protection on every outbound request.

geo-audit becomes its first consumer, via a normal package dependency.

## 2. Motivation

- It is already a separate SPM target and library product with its own tests; the seam exists.
- The parts that matter are not GEO-specific: SSRF-safe fetching (`URLValidator`),
  `robots.txt` / sitemap / `llms.txt` retrieval (`SpecialFilesFetcher`, `SitemapParser`),
  and HTML metadata extraction (`HTMLExtractor`).
- A production incident on 2026-11-02 showed the cost of the current shape: the scraper
  swallowed the transport error and every failure read as `ScraperError error 0`. That is
  now fixed in geo-audit (`cc72cce`), and the fix would be inherited by every consumer.
  A package with one owner and one test suite is where fixes like that should land.
- Other tools in this workspace (GeoSEOMCP, project-showcase) fetch pages and are
  candidates to share it rather than grow their own.

## 3. Proposed Architecture

Two layers, so the package is useful without the audit-shaped model.

| Layer | Contents | Notes |
|-------|----------|-------|
| **Core** | `HTTPClientProtocol`, `URLSessionHTTPClient`, `URLValidator`, `ScraperError`, `SpecialFilesFetcher`, `SitemapParser`, `HTMLExtractor`, `ExtractedHTML` | No GEO vocabulary. |
| **Audit model** | `ScrapedSiteData`, `CrawledSiteData`, `CrawlDepth`, `SubpageData`, `WebScraper` (orchestrator) | Carries `llmsTxt`, JSON-LD, heading structure, platform links. |

Open question 1 is whether the audit model ships in this package or stays in geo-audit.

**Dependencies to cut:** `MCPClient`. Grep shows the only use is `AnyCodableValue`
(JSON-LD storage) in `HTMLExtractor.swift` and `ScrapedSiteData.swift`. The package
should own a small `JSONValue` type, or use one from an existing package, instead of
depending on an MCP client. A scraper must not need MCP.

**Remaining dependencies:** `SwiftSoup`, `swift-log`. Both already vetted in geo-audit.

## 4. API Surface

Unchanged in this proposal except:

- `AnyCodableValue` → package-owned `JSONValue` (Codable, Sendable, Equatable). Source
  break for geo-audit only; handled in its migration step.
- `ScraperError` keeps the cases added in `cc72cce` (`networkError(url:underlying:)`) and
  its `LocalizedError` conformance.
- `URLSessionHTTPClient` is flagged by the quality gate as public but unused outside its
  module. It stays public here — consumers need it to build a `WebScraper` — but the
  gate's `legibility` note should be re-checked once a second consumer exists.

## 5. MCP Schema

Not applicable. This is a library, not an MCP server. (That is the point of removing
the `MCPClient` dependency.)

## 6. Constraints & Compliance (first pass)

- `swift-tools-version` is pinned to **6.2**, not the scaffold's 6.4. geo-audit's Dockerfile builds on
  `swift:6.2-jammy`; a newer manifest would fail its Fly build the moment it depends on this package.
- Swift 6 language mode, strict concurrency; all public types `Sendable`.
- Must build on Linux (Fly.io container, `swift:6.2-jammy`) and macOS. `URLSession` is
  imported via `FoundationNetworking` on Linux today (`HTTPClient.swift`).
- No force unwraps, no `print`, no suppression comments to satisfy the gate.
- **Known SSRF gaps to resolve before publishing, not after:**
  - `URLValidator` checks the hostname *string* only. It does not resolve DNS, so a
    public hostname that resolves to a private address passes.
  - It does not re-validate redirect targets.
  - `host.hasPrefix("fc")` / `"fd"` is meant for IPv6 unique-local addresses but also
    matches hostnames such as `fdic.gov` and `fcc.gov`.
  These are existing behaviors in geo-audit. A reusable library has to state its SSRF
  guarantees accurately; extracting it is the moment to either fix or document them.

## 7. Source & API Compatibility (first pass)

- Start at `0.x`; no stability promise until a second consumer has used it.
- geo-audit pins the package by tag. Its migration is mechanical: change imports, swap
  `AnyCodableValue` for `JSONValue`.

## 8. Backend Abstraction

Not applicable. Not compute-intensive.

## 9. Resource Budget (first pass)

Network-bound. Concurrency is bounded by `maxSubpages` (default 5) and one concurrent
special-files fetch. Needs explicit limits on response body size and per-request timeout
before publishing — today `URLSession.shared` defaults apply and no body cap exists.

## 10. Dependencies

| Dependency | Why | Status |
|------------|-----|--------|
| SwiftSoup | HTML parsing | In use |
| swift-log | Diagnostics | In use |
| ~~MCPClient~~ | ~~`AnyCodableValue`~~ | **Remove** |

## 11. Test Strategy (first pass)

- Move the existing `WebScraperTests` target across with its `MockHTTPClient`.
- Keep the `cc72cce` regression tests (transport cause preserved; `unsafeURL` not masked).
- Add tests for each SSRF gap in §6 as red tests first, per TDD.
- Add one live-network smoke test, off by default, behind an environment variable.

## 12. Architecture Decision Review (first pass)

Candidate decision records to write: (a) core / audit-model split, (b) owning `JSONValue`
versus depending on another package, (c) SSRF guarantees the package promises.

## 13. Adversarial Review (first pass)

- Hostile target site: huge body, endless redirects, slow-loris response, malformed HTML,
  malformed JSON-LD (already tolerated), sitemap index cycles.
- Hostile hostname: DNS rebinding, IPv6 literals, `fdXX.` hostnames (see §6).
- Consumer misuse: passing user-supplied URLs without validation — the default client
  validates, a custom `HTTPClientProtocol` may not. Document this.

## 14. Alternatives Considered

1. **Leave it in geo-audit.** Zero cost now; every future consumer copies the code, and
   security fixes diverge. Rejected as the long-term answer, and it remains a fine answer
   if no second consumer appears.
2. **Extract as-is, `MCPClient` dependency included.** Fastest, but forces every consumer
   to build an MCP client. Rejected.
3. **Extract only the core and leave the audit model in geo-audit.** Cleanest package,
   most migration work in geo-audit. Leading candidate; see open question 1.
4. **Adopt an existing Swift scraping package.** None found that bundles SSRF validation
   and `llms.txt` / sitemap handling; not searched exhaustively.

## 15. Future Directions

`robots.txt` compliance for the crawler itself (it currently reads the file but this
proposal does not check that crawling honors it), JS-rendered page support, conditional
requests / caching, per-host rate limiting.

## 16. Open Questions

1. Does the audit model (`ScrapedSiteData` and friends) ship in this package, or stay in geo-audit?
2. Name: `SwiftWebScraper` follows the workspace's `Swift*` convention (`SwiftMCPClient`,
   `SwiftHTTPService`). Confirm, and confirm the repo is private first.
3. Is `SwiftHTTPService` (an HTTP *server* package) relevant, or only a name neighbor? Not checked.
4. Which SSRF gaps are fixed in v0.1 versus documented as limitations?
5. Which JSON type: package-owned `JSONValue`, or reuse one that already exists in the workspace?

## 17. Documentation Strategy (first pass)

DocC catalogue carries over (`WebScraper.md`, `WebScraperGuide.md`). The guide's code
fences are checked by the gate's `doc-code` checker; keep them compiling. Add a
"Security model" article stating exactly what SSRF protection does and does not cover.

---

## Migration Plan (outline)

1. Review and approve this proposal.
2. In `SwiftWebScraper`: copy sources and tests; remove `MCPClient`; introduce `JSONValue`; green tests.
3. Fix or document the §6 SSRF gaps, red tests first.
4. Quality gate to 0/0; tag `0.1.0`.
5. In geo-audit: replace the in-repo target with the dependency; confirm 129 tests still pass; deploy.
6. Doc housekeeping in both repos (CHANGELOG, master plan, README).

## Review Checklist

- [ ] Scope split (§3) decided
- [ ] SSRF stance (§6) decided
- [ ] Dependency removal (§10) confirmed feasible
- [ ] Repo created and private before first push
