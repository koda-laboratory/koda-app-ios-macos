import Foundation

/// The upcoming menu the widgets show. The app writes it to the App Group whenever the plan or the household
/// settings change (including changes that arrive by sync); the widget extension only reads it, so it never opens
/// the database or the network. Compiled into both the app and `KodaWidgets`.
struct WidgetMenu: Codable, Sendable, Equatable {
    struct Meal: Codable, Sendable, Equatable {
        /// Localized slot name ("Comida", "Cena").
        let slotTitle: String
        /// Recipe name or free text ("Comemos fuera").
        let title: String
        /// Minutes since midnight in the household time zone.
        let minutes: Int
        let isRecipe: Bool

        /// "14:30".
        var timeText: String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    }

    struct Day: Codable, Sendable, Equatable {
        let year: Int
        let month: Int
        let day: Int
        /// In slot and time order.
        let meals: [Meal]
    }

    let timeZoneIdentifier: String
    /// From today onwards, so the widget keeps working for days without the app being opened.
    let days: [Day]

    /// `group.com.kodalabs.app`.
    static let appGroup = "group.com.kodalabs.app"
    /// The widget kind of the "Hoy" widget.
    static let widgetKind = "TodayWidget"
    static let empty = WidgetMenu(timeZoneIdentifier: TimeZone.current.identifier, days: [])

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    /// The meals planned on the day containing `date`, or `nil` when that day is outside the snapshot.
    func meals(on date: Date) -> [Meal]? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return days.first { $0.year == components.year && $0.month == components.month && $0.day == components.day }?
            .meals
    }

    /// The start of each day in the snapshot after `date`, when the widget moves on to the next day.
    func dayStarts(after date: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return days.compactMap { day in
            calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
        }
        .filter { $0 > date }
    }

    // MARK: - Storage

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("WidgetMenu.json")
    }

    static func load() -> WidgetMenu? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetMenu.self, from: data)
    }
}
