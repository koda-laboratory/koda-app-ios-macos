import Foundation
import Testing

@testable import Koda

@Suite("Shopping cycle range")
struct ShoppingCycleTests {
    @Test(
        "The cycle goes from the day after the next shopping day to the following one",
        arguments: [
            // today, shopping weekday (ISO), shopping day, from, through
            ("2026-10-22", 5, "2026-10-23", "2026-10-24", "2026-10-30"),  // Thursday, Friday shopping
            ("2026-10-23", 5, "2026-10-23", "2026-10-24", "2026-10-30"),  // the shopping day itself
            ("2026-10-24", 5, "2026-10-30", "2026-10-31", "2026-11-06"),  // Saturday → next Friday
            ("2026-10-22", 1, "2026-10-26", "2026-10-27", "2026-11-02"),  // Monday shopping
            ("2026-10-25", 7, "2026-10-25", "2026-10-26", "2026-11-01"),  // Sunday shopping on a Sunday
            ("2026-12-30", 5, "2027-01-01", "2027-01-02", "2027-01-08"),  // across the year
        ]
    )
    func cycle(today: String, weekday: Int, shoppingDay: String, from: String, through: String) throws {
        let cycle = ShoppingCycle(today: try #require(LocalDay(today)), shoppingWeekday: weekday)
        #expect(cycle.shoppingDay.description == shoppingDay)
        #expect(cycle.from.description == from)
        #expect(cycle.through.description == through)
    }

    @Test("An invalid weekday falls back to Friday")
    func invalidWeekday() {
        let cycle = ShoppingCycle(today: TestClock.thursday, shoppingWeekday: 0)
        #expect(cycle.shoppingDay.description == "2026-10-23")
    }

    @Test("Quick ranges: whole cycle, the next weekend and from today")
    func quickRanges() {
        let cycle = ShoppingCycle(today: TestClock.thursday, shoppingWeekday: 5)
        let whole = cycle.range(.untilNextShoppingDay, today: TestClock.thursday)
        #expect(whole.lowerBound.description == "2026-10-24")
        #expect(whole.upperBound.description == "2026-10-30")
        let weekend = cycle.range(.weekend, today: TestClock.thursday)
        #expect(weekend.lowerBound.description == "2026-10-24")
        #expect(weekend.upperBound.description == "2026-10-25")
        let fromToday = cycle.range(.fromToday, today: TestClock.thursday)
        #expect(fromToday.lowerBound.description == "2026-10-22")
        #expect(fromToday.upperBound.description == "2026-10-30")
    }

    @Test("ISO weekdays", arguments: [("2026-10-19", 1), ("2026-10-22", 4), ("2026-10-25", 7)])
    func isoWeekday(day: String, expected: Int) throws {
        #expect(try #require(LocalDay(day)).isoWeekday == expected)
    }
}
