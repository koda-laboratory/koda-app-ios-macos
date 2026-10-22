import Foundation

/// ISO 8601 timestamps as stored locally and exchanged with the backend (`timestamptz` columns, `client_ts`).
///
/// Postgres returns microseconds and `+00:00` offsets (`2026-10-22T10:00:00.123456+00:00`); the app writes
/// milliseconds in UTC (`2026-10-22T10:00:00.123Z`). Both parse to the same `Date`.
enum ISO8601Timestamp {
    static func string(from date: Date) -> String {
        makeFormatter(fractionalSeconds: true).string(from: date)
    }

    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let normalized = normalizingFraction(of: string)
        return makeFormatter(fractionalSeconds: true).date(from: normalized)
            ?? makeFormatter(fractionalSeconds: false).date(from: normalized)
    }

    // ISO8601DateFormatter is not Sendable, so each call builds its own (cheap compared with I/O).
    private static func makeFormatter(fractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =
            fractionalSeconds ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    /// Truncates or pads the fractional seconds to three digits, which `ISO8601DateFormatter` always accepts.
    private static func normalizingFraction(of string: String) -> String {
        guard let dot = string.firstIndex(of: ".") else { return string }
        let fractionStart = string.index(after: dot)
        let fractionEnd = string[fractionStart...].firstIndex { !$0.isNumber } ?? string.endIndex
        let digits = string[fractionStart..<fractionEnd]
        let millis = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        return String(string[..<fractionStart]) + millis + String(string[fractionEnd...])
    }
}
