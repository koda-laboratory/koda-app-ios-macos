import Foundation

extension JSONDecoder.DateDecodingStrategy {
    /// Dates returned by Supabase (GoTrue, PostgREST and the `api` Edge Function): ISO 8601 with or
    /// without fractional seconds, plus date-only values for `date` columns.
    static let supabase = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let date = parseISO8601Date(value, includingFractionalSeconds: true) { return date }
        if let date = parseISO8601Date(value, includingFractionalSeconds: false) { return date }
        if let date = supabaseDateOnlyFormatter.date(from: value) { return date }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid Supabase date: \(value)"
        )
    }
}

extension JSONDecoder {
    /// Decoder configured for every Supabase response.
    static func supabase() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .supabase
        return decoder
    }
}

private func parseISO8601Date(_ value: String, includingFractionalSeconds: Bool) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions =
        includingFractionalSeconds ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]

    return formatter.date(from: value)
}

// Shared DateFormatters are thread-safe once configured and are never mutated after creation.
private let supabaseDateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
