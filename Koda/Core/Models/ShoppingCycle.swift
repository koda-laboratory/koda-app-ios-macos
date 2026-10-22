import Foundation

/// The flexible shopping cycle (PLAN.md 3.6): the list is continuous, and the household's shopping weekday only
/// proposes the range when generating the shopping from the planning — from the day after the shopping day to
/// the next shopping day ("Compra del viernes 23 · cubre del sáb 24 al vie 30").
struct ShoppingCycle: Sendable, Equatable {
    /// The next shopping day, today included.
    let shoppingDay: LocalDay
    /// First day the shopping covers (the day after `shoppingDay`).
    let from: LocalDay
    /// Last day the shopping covers (the next shopping day).
    let through: LocalDay

    init(today: LocalDay, shoppingWeekday: Int) {
        let weekday = (1...7).contains(shoppingWeekday) ? shoppingWeekday : 5
        let daysUntil = (weekday - today.isoWeekday + 7) % 7
        let shoppingDay = today.adding(days: daysUntil)
        self.shoppingDay = shoppingDay
        self.from = shoppingDay.adding(days: 1)
        self.through = shoppingDay.adding(days: 7)
    }

    /// Quick ranges of the "Generar compra" sheet.
    enum QuickRange: String, CaseIterable, Sendable, Identifiable {
        /// The whole cycle (default).
        case untilNextShoppingDay
        /// The next Saturday and Sunday.
        case weekend
        /// From today to the end of the cycle.
        case fromToday

        var id: String { rawValue }
    }

    func range(_ quickRange: QuickRange, today: LocalDay) -> ClosedRange<LocalDay> {
        switch quickRange {
        case .untilNextShoppingDay:
            return from...through
        case .weekend:
            let saturday = today.adding(days: (6 - today.isoWeekday + 7) % 7)
            return saturday...saturday.adding(days: 1)
        case .fromToday:
            return today...max(today, through)
        }
    }
}

extension LocalDay {
    /// ISO weekday: 1 = Monday … 7 = Sunday.
    var isoWeekday: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let weekday = calendar.component(.weekday, from: startDate(in: .gmt))
        return (weekday + 5) % 7 + 1
    }

    /// Days in `range`, in order.
    static func days(in range: ClosedRange<LocalDay>) -> [LocalDay] {
        var days: [LocalDay] = []
        var current = range.lowerBound
        while current <= range.upperBound, days.count < 366 {
            days.append(current)
            current = current.adding(days: 1)
        }
        return days
    }
}
