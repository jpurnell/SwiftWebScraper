import Foundation

/// A JSON value of any shape, used to carry JSON-LD blocks whose structure is not known ahead of time.
///
/// The cases mirror JSON's own types. Integers and fractional numbers are kept apart so
/// `42` and `42.5` survive a round trip unchanged.
public enum JSONValue: Sendable, Equatable {
    /// A JSON string.
    case string(String)
    /// A JSON number with a fractional part or exponent.
    case number(Double)
    /// A JSON number that is a whole number.
    case integer(Int)
    /// A JSON `true` or `false`.
    case bool(Bool)
    /// A JSON object.
    case object([String: JSONValue])
    /// A JSON array.
    case array([JSONValue])
    /// A JSON `null`.
    case null
}

extension JSONValue: Codable {
    /// Decodes whichever JSON type the container holds.
    ///
    /// Types are tried from most to least specific, so `true` is a ``bool(_:)`` and `1` an
    /// ``integer(_:)``. A value that does not fit a type moves on to the next; one that fits none throws.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() { self = .null; return }
        if let value = Self.attempt(Bool.self, in: container) { self = .bool(value); return }
        if let value = Self.attempt(Int.self, in: container) { self = .integer(value); return }
        if let value = Self.attempt(Double.self, in: container) { self = .number(value); return }
        if let value = Self.attempt(String.self, in: container) { self = .string(value); return }
        if let value = Self.attempt([JSONValue].self, in: container) { self = .array(value); return }
        if let value = Self.attempt([String: JSONValue].self, in: container) { self = .object(value); return }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Not a JSON value")
        )
    }

    /// Encodes the value as the JSON type it represents.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    /// Decodes `type` from `container`, returning `nil` when the value does not fit `type`.
    ///
    /// Foundation reports a misfit in more than one way. A string where an `Int` was asked for is a
    /// `DecodingError.typeMismatch`, but `4.5` as an `Int` surfaces from inside the container as an
    /// internal `JSONError` that is only wrapped into a `DecodingError` at the outer boundary, so it
    /// cannot be matched by type. Any failure therefore reads as "not this type"; a value that fits
    /// none of them is thrown by `init(from:)`.
    private static func attempt<T: Decodable>(
        _ type: T.Type,
        in container: any SingleValueDecodingContainer
    ) -> T? {
        try? container.decode(type)
    }
}
