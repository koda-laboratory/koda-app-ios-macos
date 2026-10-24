import Foundation
import Synchronization
import Testing

@testable import Koda

private final class RecordingWidgetMenuRepository: WidgetMenuRepository, Sendable {
    private let state = Mutex<(menus: [WidgetMenu], clears: Int)>(([], 0))

    var published: [WidgetMenu] { state.withLock { $0.menus } }
    var clearCount: Int { state.withLock { $0.clears } }

    func publish(_ menu: WidgetMenu) { state.withLock { $0.menus.append(menu) } }
    func clear() { state.withLock { $0.clears += 1 } }
}

@Suite("Widget menu")
struct WidgetMenuServiceTests {
    @Test("The widgets get today's and the next days' meals in time order, and follow plan changes")
    func publishesPlan() async throws {
        let environment = try await FeatureEnvironment.make()
        let recipe = try await environment.recipe("Lentejas")
        let thursday = TestClock.thursday
        try await environment.planMeal.execute(NewMealPlanEntry(day: thursday, slot: .dinner, recipeID: recipe.id))
        try await environment.planMeal.execute(NewMealPlanEntry(day: thursday, slot: .lunch, freeText: "Sobras"))
        let repository = RecordingWidgetMenuRepository()
        let service = WidgetMenuServiceImpl(
            planningRepository: environment.planning,
            shoppingRepository: environment.shopping,
            meRepository: environment.meRepository,
            widgetMenuRepository: repository,
            clock: { TestClock.now }
        )

        await service.start()
        #expect(await eventually { repository.published.last?.days.first?.meals.count == 2 })
        let menu = try #require(repository.published.last)
        #expect(menu.days.count == WidgetMenuServiceImpl.days)
        #expect(menu.days.first?.day == 22)
        #expect(menu.days.first?.meals.map(\.title) == ["Sobras", "Lentejas"])
        #expect(menu.meals(on: TestClock.now)?.first?.timeText == "14:30")

        // A meal planned for tomorrow reaches the widget without restarting.
        try await environment.planMeal.execute(
            NewMealPlanEntry(day: thursday.adding(days: 1), slot: .lunch, freeText: "Comemos fuera")
        )
        #expect(await eventually { repository.published.last?.days[1].meals.first?.title == "Comemos fuera" })

        await service.stopAndClear()
        #expect(repository.clearCount == 1)
    }
}
