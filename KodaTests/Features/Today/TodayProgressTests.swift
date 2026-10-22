import Foundation
import Testing

@testable import Koda

@Suite("Today progress from slot times")
struct TodayProgressTests {
    private let day = TestClock.thursday
    private let madrid = TimeZone(identifier: "Europe/Madrid") ?? .gmt

    private func entry(
        _ slot: MealSlot,
        recipe: Bool = true,
        consumed: Bool = false,
        skipped: Bool = false,
        time: LocalTime? = nil
    ) -> MealPlanEntry {
        MealPlanEntry(
            id: UUID(),
            day: day,
            slot: slot,
            recipeID: recipe ? UUID() : nil,
            recipeName: recipe ? "Receta \(slot.rawValue)" : nil,
            recipeEmoji: nil,
            freeText: recipe ? nil : "Comemos fuera",
            servings: 2,
            note: nil,
            position: 0,
            draftID: nil,
            consumptionID: consumed ? UUID() : nil,
            scheduledTime: time,
            skippedAt: skipped ? .now : nil
        )
    }

    /// Madrid is UTC+2 on 22 October 2026.
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        LocalTime(hour: hour, minute: minute).date(on: day, in: madrid)
    }

    @Test("Meals count as done once their slot time passes; the first pending one is next")
    func doneByTime() {
        let entries = [entry(.breakfast), entry(.lunch), entry(.dinner)]
        let progress = TodayProgress(entries: entries, day: day, slotTimes: .default, now: at(15), timeZone: madrid)
        #expect(progress.doneCount == 2)
        #expect(progress.totalCount == 3)
        #expect(progress.nextMeal?.entry.slot == .dinner)
        #expect(progress.meals.map(\.state) == [.done, .done, .next])
        #expect(TodayProgress.bandSlots.map(progress.isBandDone) == [true, true, false])
    }

    @Test("Before breakfast nothing is done; exactly at the time it is")
    func boundaries() {
        let entries = [entry(.breakfast), entry(.lunch)]
        let early = TodayProgress(entries: entries, day: day, slotTimes: .default, now: at(8, 59), timeZone: madrid)
        #expect(early.doneCount == 0)
        #expect(early.meals.map(\.state) == [.next, .later])
        let onTime = TodayProgress(entries: entries, day: day, slotTimes: .default, now: at(9), timeZone: madrid)
        #expect(onTime.doneCount == 1)
    }

    @Test("Free text never counts and a skipped meal is left out")
    func freeTextAndSkipped() {
        let entries = [entry(.lunch, recipe: false), entry(.dinner, skipped: true), entry(.breakfast)]
        let progress = TodayProgress(entries: entries, day: day, slotTimes: .default, now: at(22), timeZone: madrid)
        #expect(progress.totalCount == 1)
        #expect(progress.doneCount == 1)
        #expect(progress.meals.first { $0.entry.slot == .lunch }?.state == .notCounted)
        #expect(progress.meals.first { $0.entry.slot == .dinner }?.state == .skipped)
        #expect(progress.isBandDone(.dinner) == false)
    }

    @Test("A consumption marks the meal as done early; an own time and household times move the deadline")
    func consumptionsAndTimes() {
        let custom = SlotTimes(strings: ["dinner": "20:00"])
        let entries = [entry(.dinner, consumed: true), entry(.lunch, time: LocalTime(hour: 16, minute: 0))]
        let progress = TodayProgress(entries: entries, day: day, slotTimes: custom, now: at(15), timeZone: madrid)
        #expect(progress.meals.map(\.entry.slot) == [.lunch, .dinner])
        #expect(progress.meals.map(\.state) == [.next, .done])
        #expect(progress.meals.first?.time.description == "16:00")
        #expect(custom.dinner.description == "20:00")
        #expect(custom.lunch == SlotTimes.default.lunch)
    }

    @Test(
        "Local times parse HH:MM and HH:MM:SS",
        arguments: [("09:00", "09:00"), ("21:30:00", "21:30"), ("7:5", "07:05")]
    )
    func localTime(input: String, expected: String) throws {
        #expect(try #require(LocalTime(input)).description == expected)
    }
}
