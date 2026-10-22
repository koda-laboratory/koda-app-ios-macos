import Foundation

/// A calendar day without a time (`date` columns such as `meal_plan_entries.date`), interpreted in the
/// household time zone (`Europe/Madrid` by default).
struct LocalDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `yyyy-MM-dd`.
    init?(_ string: String) {
        let parts = string.prefix(10).split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            (1...12).contains(month), (1...31).contains(day)
        else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    init(date: Date, timeZone: TimeZone) {
        let components = Self.calendar(timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    static func today(in timeZone: TimeZone = .household, now: Date = .now) -> LocalDay {
        LocalDay(date: now, timeZone: timeZone)
    }

    /// `yyyy-MM-dd`, the wire and database representation.
    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    func adding(days: Int) -> LocalDay {
        let calendar = Self.calendar(.gmt)
        let date = calendar.date(byAdding: .day, value: days, to: startDate(in: .gmt)) ?? startDate(in: .gmt)
        return LocalDay(date: date, timeZone: .gmt)
    }

    /// The Monday of the ISO week that contains this day.
    var startOfWeek: LocalDay {
        let weekday = Self.calendar(.gmt).component(.weekday, from: startDate(in: .gmt))
        // `weekday`: 1 = Sunday … 7 = Saturday.
        let daysFromMonday = (weekday + 5) % 7
        return adding(days: -daysFromMonday)
    }

    func startDate(in timeZone: TimeZone) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return Self.calendar(timeZone).date(from: components) ?? .distantPast
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

extension TimeZone {
    /// Default household time zone until `/me` provides one.
    static let household = TimeZone(identifier: "Europe/Madrid") ?? .current
}
