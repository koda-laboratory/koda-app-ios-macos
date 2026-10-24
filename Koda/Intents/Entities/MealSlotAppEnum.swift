import AppIntents

/// A meal slot as a Siri / Shortcuts parameter. Raw values are a public contract: never rename or reorder.
enum MealSlotAppEnum: String, AppEnum {
    case breakfast
    case lunch
    case snack
    case dinner

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.slot.type")
    static let caseDisplayRepresentations: [MealSlotAppEnum: DisplayRepresentation] = [
        .breakfast: DisplayRepresentation(title: "slot.breakfast"),
        .lunch: DisplayRepresentation(title: "slot.lunch"),
        .snack: DisplayRepresentation(title: "slot.snack"),
        .dinner: DisplayRepresentation(title: "slot.dinner"),
    ]

    var slot: MealSlot {
        switch self {
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .snack: .snack
        case .dinner: .dinner
        }
    }
}
