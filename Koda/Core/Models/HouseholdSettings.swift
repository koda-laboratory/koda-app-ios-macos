import Foundation

/// A wall-clock time without a date (`HH:MM` or `HH:MM:SS`), interpreted in the household time zone.
struct LocalTime: Hashable, Comparable, Sendable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// Parses `HH:MM` and `HH:MM:SS`.
    init?(_ string: String) {
        let parts = string.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }
        self.init(hour: hour, minute: minute)
    }

    /// `HH:MM`, the representation of `households.slot_times` and of the UI.
    var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// `HH:MM:SS`, the representation of `meal_plan_entries.scheduled_time` (`time` column).
    var databaseValue: String {
        String(format: "%02d:%02d:00", hour, minute)
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }

    /// The instant of this time on `day` in `timeZone`.
    func date(on day: LocalDay, in timeZone: TimeZone) -> Date {
        day.startDate(in: timeZone).addingTimeInterval(TimeInterval(minutesSinceMidnight * 60))
    }

    static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// The time of each meal of the day (`households.slot_times`).
struct SlotTimes: Sendable, Equatable {
    var breakfast: LocalTime
    var lunch: LocalTime
    var snack: LocalTime
    var dinner: LocalTime

    static let `default` = SlotTimes(
        breakfast: LocalTime(hour: 9, minute: 0),
        lunch: LocalTime(hour: 14, minute: 30),
        snack: LocalTime(hour: 18, minute: 0),
        dinner: LocalTime(hour: 21, minute: 30)
    )

    subscript(slot: MealSlot) -> LocalTime {
        get {
            switch slot {
            case .breakfast: breakfast
            case .lunch: lunch
            case .snack: snack
            case .dinner: dinner
            }
        }
        set {
            switch slot {
            case .breakfast: breakfast = newValue
            case .lunch: lunch = newValue
            case .snack: snack = newValue
            case .dinner: dinner = newValue
            }
        }
    }

    /// Missing or invalid slots keep their default.
    init(strings: [String: String]) {
        var times = SlotTimes.default
        for slot in MealSlot.allCases {
            if let value = strings[slot.rawValue], let time = LocalTime(value) {
                times[slot] = time
            }
        }
        self = times
    }

    init(breakfast: LocalTime, lunch: LocalTime, snack: LocalTime, dinner: LocalTime) {
        self.breakfast = breakfast
        self.lunch = lunch
        self.snack = snack
        self.dinner = dinner
    }

    var strings: [String: String] {
        Dictionary(uniqueKeysWithValues: MealSlot.allCases.map { ($0.rawValue, self[$0].description) })
    }
}

/// Household preferences edited in Profile (`PATCH /households/:id/settings`).
struct HouseholdSettings: Sendable, Equatable {
    var slotTimes: SlotTimes
    /// ISO weekday of the usual shopping day: 1 = Monday … 7 = Sunday.
    var shoppingWeekday: Int

    static let `default` = HouseholdSettings(slotTimes: .default, shoppingWeekday: 5)
}
