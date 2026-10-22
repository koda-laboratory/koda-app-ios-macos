import Foundation

struct MealPlanEntry: Sendable, Equatable, Identifiable {
    let id: UUID
    let day: LocalDay
    let slot: MealSlot
    let recipeID: UUID?
    let recipeName: String?
    let recipeEmoji: String?
    let freeText: String?
    let servings: Double?
    let note: String?
    let position: Int
    /// Set while the entry belongs to a pending draft.
    let draftID: UUID?
    /// The consumption logged for this entry (automatic at the meal time, or manual).
    let consumptionID: UUID?
    /// Own time of this meal ("hoy cenamos a las 20:00"); `nil` uses the household slot time.
    var scheduledTime: LocalTime?
    /// Set by "No lo comimos": the meal does not count and is not auto-logged again.
    var skippedAt: Date?

    var title: String { recipeName ?? freeText ?? "" }
    var isConsumed: Bool { consumptionID != nil }
    var isSkipped: Bool { skippedAt != nil }
    /// Free-text entries ("Comemos fuera") never become consumptions.
    var isRecipe: Bool { recipeID != nil }

    /// The effective time of the meal.
    func time(using slotTimes: SlotTimes) -> LocalTime {
        scheduledTime ?? slotTimes[slot]
    }
}

struct DayPlan: Sendable, Equatable, Identifiable {
    let day: LocalDay
    /// Ordered by slot and position.
    let meals: [MealPlanEntry]

    var id: LocalDay { day }

    func meals(in slot: MealSlot) -> [MealPlanEntry] {
        meals.filter { $0.slot == slot }
    }
}

/// Monday to Sunday.
struct WeekPlan: Sendable, Equatable {
    let startDay: LocalDay
    let days: [DayPlan]

    init(containing day: LocalDay, entries: [MealPlanEntry]) {
        let start = day.startOfWeek
        let byDay = Dictionary(grouping: entries, by: \.day)
        self.startDay = start
        self.days = (0..<7).map { offset in
            let current = start.adding(days: offset)
            return DayPlan(day: current, meals: MealPlanEntry.ordered(byDay[current] ?? []))
        }
    }
}

enum MealPlanDraftStatus: String, Sendable, Codable {
    case pending
    case accepted
    case discarded
}

enum MealPlanDraftSource: String, Sendable, Codable {
    case mcp
    case app
    /// Proposed by an AI assistant other than the MCP.
    case aiGenerated = "ai"
}

/// A proposed planning (usually from Claude through the MCP) that the household reviews.
struct MealPlanDraft: Sendable, Equatable, Identifiable {
    let id: UUID
    let fromDay: LocalDay
    let toDay: LocalDay
    let status: MealPlanDraftStatus
    let source: MealPlanDraftSource
    let rationale: String?
    let entries: [MealPlanEntry]
}

struct NewMealPlanEntry: Sendable, Equatable {
    var day: LocalDay
    var slot: MealSlot
    var recipeID: UUID?
    var freeText: String?
    var servings: Double?
    var note: String?
    var scheduledTime: LocalTime?
}

/// Changes to an existing planned meal (move, swap the recipe, change the time).
struct MealPlanEntryUpdate: Sendable, Equatable {
    var day: LocalDay
    var slot: MealSlot
    var recipeID: UUID?
    var freeText: String?
    var servings: Double?
    var scheduledTime: LocalTime?
}

/// Who logged a consumption (`consumptions.source`).
enum ConsumptionSource: String, Sendable, Codable {
    case auto
    case manual
    case siri
    case mcp
}

struct Consumption: Sendable, Equatable, Identifiable {
    let id: UUID
    let recipeID: UUID
    let day: LocalDay
    let slot: MealSlot?
    let servings: Double?
    let mealPlanEntryID: UUID?
}

struct NewConsumption: Sendable, Equatable {
    var recipeID: UUID
    var day: LocalDay
    var slot: MealSlot?
    var servings: Double?
    var mealPlanEntryID: UUID?
    var source: ConsumptionSource = .manual
}

extension MealPlanEntry {
    static func ordered(_ entries: [MealPlanEntry]) -> [MealPlanEntry] {
        entries.sorted { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            if lhs.slot != rhs.slot { return lhs.slot < rhs.slot }
            return lhs.position < rhs.position
        }
    }
}

extension MealPlanEntry {
    /// Eaten (or considered eaten): a recipe meal not skipped whose time has passed or that has a consumption.
    func isEaten(now: Date, slotTimes: SlotTimes, timeZone: TimeZone) -> Bool {
        guard isRecipe, !isSkipped else { return false }
        return isConsumed || time(using: slotTimes).date(on: day, in: timeZone) <= now
    }
}
