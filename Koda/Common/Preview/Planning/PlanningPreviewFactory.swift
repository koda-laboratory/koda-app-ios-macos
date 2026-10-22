import SwiftUI

/// Planning previews over the seeded in-memory database, and sample values for components.
@MainActor
enum PlanningPreviewFactory {
    static func makePlanningView(container: DependencyContainer = PreviewContainer.populated) -> some View {
        AppTabNavigationStack(tab: .planning) {
            PlanningView(viewModel: Assembly.makePlanningViewModel(container: container), container: container)
        }
        .environment(AppRouter(selectedTab: .planning))
    }

    static func makePlanMealViewModel(container: DependencyContainer = PreviewContainer.populated) -> PlanMealViewModel
    {
        Assembly.makePlanMealViewModel(
            request: .new(day: LocalDay.today(), slot: .dinner, recipeID: nil),
            container: container
        )
    }

    static func makeDraftReviewView(container: DependencyContainer = PreviewContainer.populated) -> some View {
        DraftReviewView(
            viewModel: Assembly.makeDraftReviewViewModel(draftID: PreviewDatabase.uuid(700), container: container)
        )
    }

    static func entry(_ index: Int, day: LocalDay, slot: MealSlot, name: String?, text: String? = nil) -> MealPlanEntry
    {
        MealPlanEntry(
            id: PreviewDatabase.uuid(index),
            day: day,
            slot: slot,
            recipeID: name == nil ? nil : PreviewDatabase.uuid(index + 100),
            recipeName: name,
            recipeEmoji: nil,
            freeText: text,
            servings: 2,
            note: nil,
            position: 0,
            draftID: nil,
            consumptionID: nil
        )
    }

    static var dayPlan: DayPlan {
        let day = PresentationPreviewFactory.today
        return DayPlan(
            day: day,
            meals: [
                entry(1, day: day, slot: .breakfast, name: "Galletas de avena"),
                entry(2, day: day, slot: .lunch, name: "Curry de garbanzos"),
                entry(3, day: day, slot: .dinner, name: nil, text: "Comemos fuera"),
            ]
        )
    }

    static var week: WeekPlan {
        let names = ["Pasta con pesto", "Anvorgesitas", "Curry de garbanzos", "Ramen", "Paella", "Sopa", "Burrito"]
        let entries = PresentationPreviewFactory.week.enumerated().flatMap { index, day in
            [
                entry(10 + index, day: day, slot: .breakfast, name: "Galletas de avena"),
                entry(20 + index, day: day, slot: .lunch, name: names[index]),
                index == 4
                    ? entry(30 + index, day: day, slot: .dinner, name: nil, text: "Comemos fuera")
                    : entry(30 + index, day: day, slot: .dinner, name: "Ensalada César"),
            ]
        }
        return WeekPlan(containing: PresentationPreviewFactory.today, entries: entries)
    }

    static var draft: MealPlanDraft {
        let day = PresentationPreviewFactory.today.adding(days: 4)
        return MealPlanDraft(
            id: PreviewDatabase.uuid(700),
            fromDay: day,
            toDay: day.adding(days: 6),
            status: .pending,
            source: .mcp,
            rationale: "14 comidas sin repetir nada de las últimas dos semanas y cenas ligeras, como pediste.",
            entries: [entry(40, day: day, slot: .lunch, name: "Gnocchi")]
        )
    }
}
