import SwiftUI

/// Hoy (approved mockups `Today` and `TodayDark`).
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    private let container: DependencyContainer

    init(viewModel: TodayViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KodaSpacing.l - 2) {
                ScreenHeader(subtitle: dateLine, title: greeting) {
                    if PlatformIdiom.current == .phone {
                        AvatarButton(
                            name: viewModel.household?.displayName,
                            emoji: viewModel.household?.avatarEmoji
                        ) {
                            Task { await viewModel.send(.openProfile) }
                        }
                    }
                }

                TodayHeroCard(progress: viewModel.progress)

                ForEach(viewModel.dueFrozenItems) { item in
                    DefrostCard(item: item, mealText: defrostText(for: item)) {
                        Task { await viewModel.send(.resolveFrozenItem(item)) }
                    }
                }

                TodayMealsSection(viewModel: viewModel)

                if let shopping = viewModel.shopping {
                    ShoppingSummaryCard(
                        pendingCount: shopping.pendingProductCount,
                        stores: shopping.pendingCountByStore
                    ) {
                        router.selectedTab = .shopping
                    }
                }

                if let suggestion = viewModel.suggestion,
                    let days = suggestion.stats.daysSinceLastEaten(today: viewModel.today)
                {
                    SuggestionCard(recipeName: suggestion.recipe.name, weeks: max(days / 7, 1)) {
                        Task { await viewModel.send(.planSuggestion(suggestion.recipe.id)) }
                    }
                }

                ForEach(viewModel.drafts) { draft in
                    DraftBanner(rangeText: draftRange(draft)) {
                        router.navigate(to: .mealPlanDraft(id: draft.id), in: .today)
                    }
                }
            }
            .padding(.horizontal, KodaSpacing.l - 4)
            .padding(.top, KodaSpacing.s)
            .padding(.bottom, KodaSpacing.xl * 3)
            .frame(maxWidth: KodaSize.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(KodaColor.background)
        .navigationTitle(Text("tab.today"))
        .platformHidesNavigationBar()
        .toast($viewModel.toast)
        .sheet(item: $viewModel.presentedSheet) { sheet in
            TodaySheetContent(sheet: sheet, container: container)
        }
        .task { await viewModel.send(.appeared) }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await viewModel.send(.tick)
            }
        }
        .refreshable { await viewModel.send(.tick) }
    }

    private var greeting: String {
        let name = viewModel.household?.displayName ?? ""
        return name.isEmpty
            ? String(localized: "today.greeting.anonymous") : String(localized: "today.greeting \(name)")
    }

    private var dateLine: String {
        KodaFormat.longDay(viewModel.today, locale: locale).capitalizedFirst
    }

    private func draftRange(_ draft: MealPlanDraft) -> String {
        "\(KodaFormat.day(draft.fromDay, .dateTime.day().month(.abbreviated), locale: locale)) – "
            + KodaFormat.day(draft.toDay, .dateTime.day().month(.abbreviated), locale: locale)
    }

    private func defrostText(for item: FrozenItem) -> String {
        guard let meal = item.meal, let recipe = meal.recipeName else { return "" }
        let time = (meal.scheduledTime ?? viewModel.slotTimes[meal.slot]).description
        let dayOffset = meal.day == viewModel.today ? 0 : (meal.day == viewModel.today.adding(days: 1) ? 1 : 2)
        switch dayOffset {
        case 0: return String(localized: "today.defrost.meal.today \(time) \(recipe)")
        case 1: return String(localized: "today.defrost.meal.tomorrow \(time) \(recipe)")
        default:
            return String(
                localized:
                    "today.defrost.meal.day \(KodaFormat.weekdayAndDay(meal.day, locale: locale)) \(time) \(recipe)"
            )
        }
    }
}

/// "Comidas de hoy · Semana" and the meal cards.
private struct TodayMealsSection: View {
    let viewModel: TodayViewModel
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            SectionHeader(titleKey: "today.meals.title", actionKey: "today.meals.week") {
                router.selectedTab = .planning
            }
            let meals = viewModel.progress.meals
            if meals.isEmpty, viewModel.state == .ready {
                EmptyStateView(
                    titleKey: "today.empty.title",
                    messageKey: "today.empty.message",
                    actionKey: "today.empty.action"
                ) {
                    router.request(.planMeal)
                }
                .kodaCardBackground()
            }
            ForEach(meals) { meal in
                TodayMealCard(
                    meal: meal,
                    detail: detail(for: meal),
                    onChange: { Task { await viewModel.send(.changeMeal(meal.entry)) } },
                    onSkip: { Task { await viewModel.send(.skipMeal(meal.entry)) } }
                )
            }
        }
    }

    private func detail(for meal: TodayProgress.Meal) -> String {
        let recipe = viewModel.recipe(for: meal.entry)?.recipe
        let minutes = recipe?.timeMinutes.map { String(localized: "recipe.minutes \($0)") }
        let nutrients = recipe?.nutrients.prefix(2).map { String(localized: $0.titleResource) }.joined(separator: " · ")
        return KodaFormat.joined([meal.time.description, minutes, nutrients])
    }
}

/// Sheets of Hoy: plan or change a meal, and Profile (iPhone).
private struct TodaySheetContent: View {
    let sheet: TodaySheet
    let container: DependencyContainer

    var body: some View {
        switch sheet {
        case .planMeal(let request):
            PlanMealSheet(viewModel: Assembly.makePlanMealViewModel(request: request, container: container))
        case .profile:
            NavigationStack {
                ProfileView(viewModel: Assembly.makeProfileViewModel(container: container), presentation: .sheet)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Today · iPhone") {
        TodayPreviewFactory.makeTodayView()
            .kodaPreview()
    }

    #Preview("Today · empty") {
        TodayPreviewFactory.makeTodayView(container: PreviewContainer.empty)
            .kodaPreview()
    }

    #Preview("Today · dark") {
        TodayPreviewFactory.makeTodayView()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Today · Mac", traits: .fixedLayout(width: 1100, height: 800)) {
        TodayPreviewFactory.makeTodayView()
            .kodaPreview()
    }
#endif
