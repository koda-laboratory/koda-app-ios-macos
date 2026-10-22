import Foundation

/// State of one planned meal for the day's progress, computed locally from the slot times so it also works
/// offline (the server creates the definitive consumption every 15 minutes).
enum MealProgressState: Sendable, Equatable {
    /// Its time has passed (or a consumption exists).
    case done
    /// The first pending meal of the day.
    case next
    case later
    /// "No lo comimos".
    case skipped
    /// Free text ("Comemos fuera"): never counted.
    case notCounted
}

/// The day's progress for the Today hero: "2 de 3 comidas hechas".
struct TodayProgress: Sendable, Equatable {
    struct Meal: Sendable, Equatable, Identifiable {
        let entry: MealPlanEntry
        let time: LocalTime
        let state: MealProgressState

        var id: UUID { entry.id }
    }

    /// Meals of the day in time order.
    let meals: [Meal]

    /// The three bands of the hero arcs, outermost first.
    static let bandSlots: [MealSlot] = [.breakfast, .lunch, .dinner]

    var countedMeals: [Meal] { meals.filter { $0.state != .notCounted && $0.state != .skipped } }
    var doneCount: Int { countedMeals.filter { $0.state == .done }.count }
    var totalCount: Int { countedMeals.count }
    var nextMeal: Meal? { meals.first { $0.state == .next } }

    /// `true` when every counted meal of `slot` is done; `false` when one is pending or nothing is planned.
    func isBandDone(_ slot: MealSlot) -> Bool {
        let slotMeals = countedMeals.filter { $0.entry.slot == slot }
        return !slotMeals.isEmpty && slotMeals.allSatisfy { $0.state == .done }
    }

    init(meals: [Meal]) {
        self.meals = meals
    }

    /// - Parameters:
    ///   - entries: the planned meals of `day`.
    ///   - now: the current instant; a recipe meal counts as done once its time has passed.
    init(entries: [MealPlanEntry], day: LocalDay, slotTimes: SlotTimes, now: Date, timeZone: TimeZone) {
        let sorted = entries.sorted { lhs, rhs in
            let lhsTime = lhs.time(using: slotTimes)
            let rhsTime = rhs.time(using: slotTimes)
            if lhsTime != rhsTime { return lhsTime < rhsTime }
            if lhs.slot != rhs.slot { return lhs.slot < rhs.slot }
            return lhs.position < rhs.position
        }
        var foundNext = false
        self.meals = sorted.map { entry in
            let time = entry.time(using: slotTimes)
            let state: MealProgressState
            if !entry.isRecipe {
                state = .notCounted
            } else if entry.isSkipped {
                state = .skipped
            } else if entry.isConsumed || time.date(on: day, in: timeZone) <= now {
                state = .done
            } else if !foundNext {
                foundNext = true
                state = .next
            } else {
                state = .later
            }
            return Meal(entry: entry, time: time, state: state)
        }
    }
}
