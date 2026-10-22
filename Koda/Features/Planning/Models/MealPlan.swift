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
    /// The consumption logged for this entry ("Marcar como comido").
    let consumptionID: UUID?

    var title: String { recipeName ?? freeText ?? "" }
    var isConsumed: Bool { consumptionID != nil }
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
