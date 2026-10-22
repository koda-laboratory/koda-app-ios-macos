import SwiftUI

/// Today previews: the screen over the seeded in-memory database, and sample progress values.
@MainActor
enum TodayPreviewFactory {
    static func makeTodayView(container: DependencyContainer = PreviewContainer.populated) -> some View {
        AppTabNavigationStack(tab: .today) {
            TodayView(viewModel: Assembly.makeTodayViewModel(container: container), container: container)
        }
        .environment(AppRouter())
    }

    /// Breakfast, lunch and dinner of today with `done` meals already eaten.
    static func progress(done: Int) -> TodayProgress {
        let day = PresentationPreviewFactory.today
        let names = ["Galletas de avena", "Curry de garbanzos", "Ensalada César"]
        let entries = [MealSlot.breakfast, .lunch, .dinner].enumerated().map { index, slot in
            MealPlanEntry(
                id: PreviewDatabase.uuid(990 + index),
                day: day,
                slot: slot,
                recipeID: PreviewDatabase.uuid(201 + index),
                recipeName: names[index],
                recipeEmoji: nil,
                freeText: nil,
                servings: 2,
                note: nil,
                position: 0,
                draftID: nil,
                consumptionID: index < done ? PreviewDatabase.uuid(980 + index) : nil
            )
        }
        return TodayProgress(
            entries: entries,
            day: day,
            slotTimes: .default,
            now: day.startDate(in: .household),
            timeZone: .household
        )
    }

    static let frozenItem = FrozenItem(
        id: PreviewDatabase.uuid(900),
        productID: PreviewDatabase.uuid(110),
        productName: "Carrilleras de cerdo",
        shoppingEntryID: nil,
        shoppingEntryItemID: nil,
        meal: nil,
        frozenAt: nil,
        defrostRemindAt: .now
    )
}
