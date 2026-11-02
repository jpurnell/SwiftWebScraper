import Testing
@testable import SwiftWebScraper

@Suite("SwiftWebScraper scaffold")
struct SwiftWebScraperTests {
    @Test("The namespace is an uninhabited enum that carries no state")
    func namespaceHasNoState() {
        #expect(MemoryLayout<SwiftWebScraper>.size == 0)
    }
}
