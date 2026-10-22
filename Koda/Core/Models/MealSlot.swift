/// `public.meal_slot`: the meals of a day, in display order.
enum MealSlot: String, CaseIterable, Sendable, Codable, Comparable {
    case breakfast
    case lunch
    case snack
    case dinner

    private var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    static func < (lhs: MealSlot, rhs: MealSlot) -> Bool {
        lhs.order < rhs.order
    }
}
