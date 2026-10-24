import AppIntents
import SwiftUI

/// "Qué hay hoy de comer en Koda": today's planned meals, spoken and as a card. Reads the local database, so it
/// works offline and with the iPhone locked.
struct TodayMealsIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.today.title"
    static let description = IntentDescription("intent.today.description")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "intent.slot.type")
    var slot: MealSlotAppEnum?

    @Dependency var services: IntentServices

    static var parameterSummary: some ParameterSummary {
        Summary("intent.today.summary \(\.$slot)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let slotTimes = await services.slotTimes()
        let meals = (await services.todayMeals()?.meals ?? [])
            .filter { !$0.isSkipped && (slot == nil || $0.slot == slot?.slot) }
            .sorted { $0.time(using: slotTimes) < $1.time(using: slotTimes) }
        let lines = meals.map { meal in
            SnippetMeal(
                slotTitle: String(localized: meal.slot.titleResource),
                title: meal.title,
                time: meal.time(using: slotTimes).description
            )
        }
        guard !lines.isEmpty else {
            return .result(dialog: "intent.today.nothing", view: TodayMealsSnippetView(meals: []))
        }
        let spoken = lines.map { "\($0.slotTitle.lowercased()): \($0.title)" }.joined(separator: ". ")
        return .result(dialog: "intent.today.dialog \(spoken)", view: TodayMealsSnippetView(meals: lines))
    }
}
