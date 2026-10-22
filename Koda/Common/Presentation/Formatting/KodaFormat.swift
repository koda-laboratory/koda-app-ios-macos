import Foundation

/// Locale-aware formatting of days, times and quantities shared by every screen.
enum KodaFormat {
    /// Formats a calendar day. The day is anchored at noon UTC and formatted in UTC so it never shifts.
    static func day(_ day: LocalDay, _ style: Date.FormatStyle, locale: Locale = .current) -> String {
        var format = style
        format.timeZone = .gmt
        format.locale = locale
        return day.startDate(in: .gmt).addingTimeInterval(12 * 3600).formatted(format)
    }

    /// "jueves, 22 de octubre".
    static func longDay(_ value: LocalDay, locale: Locale = .current) -> String {
        day(value, .dateTime.weekday(.wide).day().month(.wide), locale: locale)
    }

    /// "sáb 24".
    static func shortDay(_ value: LocalDay, locale: Locale = .current) -> String {
        day(value, .dateTime.weekday(.abbreviated).day(), locale: locale)
    }

    /// "sáb 24 oct".
    static func shortDayMonth(_ value: LocalDay, locale: Locale = .current) -> String {
        day(value, .dateTime.weekday(.abbreviated).day().month(.abbreviated), locale: locale)
    }

    /// "jueves 22".
    static func weekdayAndDay(_ value: LocalDay, locale: Locale = .current) -> String {
        day(value, .dateTime.weekday(.wide).day(), locale: locale)
    }

    /// "J" for the week strip.
    static func weekdayInitial(_ value: LocalDay, locale: Locale = .current) -> String {
        day(value, .dateTime.weekday(.narrow), locale: locale)
    }

    /// "22".
    static func dayNumber(_ value: LocalDay) -> String {
        String(value.day)
    }

    /// "octubre".
    static func monthName(_ value: LocalDay, locale: Locale = .current) -> String {
        day(value, .dateTime.month(.wide), locale: locale)
    }

    /// ISO week number ("Semana 43").
    static func weekNumber(_ value: LocalDay) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        return calendar.component(.weekOfYear, from: value.startDate(in: .gmt))
    }

    /// "300 g", "4", "1,5 kg".
    static func quantity(_ quantity: Double?, unit: String?, locale: Locale = .current) -> String {
        let number = quantity.map { $0.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) }
        return [number, unit].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func joined(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

extension String {
    /// Capitalizes only the first letter ("jueves, 22 de octubre" → "Jueves, 22 de octubre").
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
