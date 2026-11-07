import Testing
import Foundation
@testable import SwiftWebScraper

@Suite("JSONValue")
struct JSONValueTests {

    private func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test("Decodes each JSON scalar to its own case")
    func scalars() throws {
        #expect(try decode("\"hi\"") == .string("hi"))
        #expect(try decode("42") == .integer(42))
        #expect(try decode("4.5") == .number(4.5))
        #expect(try decode("true") == .bool(true))
        #expect(try decode("null") == .null)
    }

    @Test("Decodes nested arrays and objects")
    func containers() throws {
        let value = try decode(#"{"@type":"Organization","sameAs":["a","b"],"n":1}"#)
        #expect(value == .object([
            "@type": .string("Organization"),
            "sameAs": .array([.string("a"), .string("b")]),
            "n": .integer(1)
        ]))
    }

    @Test("Round-trips through JSON encoding")
    func roundTrip() throws {
        let original: JSONValue = .object(["a": .array([.integer(1), .null, .bool(false)]), "b": .string("x")])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(JSONValue.self, from: data) == original)
    }

    @Test("Malformed JSON is a thrown error, not a silent value")
    func malformed() {
        #expect(throws: (any Error).self) { try decode("{\"a\":") }
    }
}

@Suite("ScraperError")
struct ScraperErrorTests {
    @Test("localizedDescription carries the cause rather than an opaque enum code")
    func errorsAreDescriptive() {
        let network = ScraperError.networkError(url: "https://example.com", underlying: "timed out")
        #expect(network.localizedDescription.contains("https://example.com"))
        #expect(network.localizedDescription.contains("timed out"))
        #expect(ScraperError.fetchFailed(url: "https://example.com", statusCode: 503).localizedDescription.contains("503"))
        #expect(ScraperError.unsafeURL("https://10.0.0.1", reason: "private").localizedDescription.contains("private"))
    }
}
