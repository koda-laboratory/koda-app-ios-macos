/// Today's planned meals, grouped by slot for the "Hoy" cards.
struct TodayMeals: Sendable, Equatable {
    let day: LocalDay
    let meals: [MealPlanEntry]

    /// Slots with at least one meal, in display order.
    var slots: [MealSlot] {
        MealSlot.allCases.filter { slot in meals.contains { $0.slot == slot } }
    }

    func meals(in slot: MealSlot) -> [MealPlanEntry] {
        meals.filter { $0.slot == slot }
    }

    var pendingCount: Int {
        meals.filter { !$0.isConsumed }.count
    }
}
