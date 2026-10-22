import Foundation

/// An arbitrary JSON value. Used for the parts of the sync contract whose shape depends on the table
/// (`fields` of a mutation, rows of `/sync/pull`).
enum JSONValue: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var int64Value: Int64? {
        switch self {
        case .int(let value): value
        case .double(let value): Int64(exactly: value)
        case .string(let value): Int64(value)
        default: nil
        }
    }

    /// Compact JSON text, for storing arrays and objects in TEXT columns.
    func jsonText() throws -> String {
        let data = try JSONEncoder.sortedKeys.encode(self)
        return String(bytes: data, encoding: .utf8) ?? "null"
    }

    static func parse(jsonText: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(jsonText.utf8))
    }
}

extension JSONEncoder {
    /// Deterministic output (stable keys) for stored JSON.
    static var sortedKeys: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
