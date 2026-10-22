import SwiftUI

/// Planning (approved mockups `Planning` on iPhone and `MacPlanning` on the Mac): one screen whose layout adapts
/// to the width — day sections on a compact iPhone, the 7 × slots grid with drag and drop on the Mac.
struct PlanningView: View {
    @State private var viewModel: PlanningViewModel
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    private let container: DependencyContainer

    init(viewModel: PlanningViewModel, container: DependencyContainer = .shared) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        Group {
            if isCompact {
                PlanningCompactContent(viewModel: viewModel, header: header)
            } else {
                PlanningGridContent(viewModel: viewModel, header: header)
            }
        }
        .background(KodaColor.background)
        .navigationTitle(Text("tab.planning"))
        .platformHidesNavigationBar()
        .toolbar {
            if !isCompact {
                ToolbarItemGroup(placement: .primaryAction) {
                    ForEach(viewModel.drafts) { draft in
                        Button("planning.draft.review-short") {
                            router.navigate(to: .mealPlanDraft(id: draft.id), in: .planning)
                        }
                    }
                    Button("planning.generate-shopping", systemImage: "bag") {
                        Task { await viewModel.send(.generateShopping) }
                    }
                }
            }
        }
        .toast($viewModel.toast)
        .sheet(item: $viewModel.presentedSheet) { sheet in
            switch sheet {
            case .planMeal(let request):
                PlanMealSheet(viewModel: Assembly.makePlanMealViewModel(request: request, container: container))
            case .generateShopping:
                GenerateShoppingSheet(viewModel: Assembly.makeGenerateShoppingViewModel(container: container))
            }
        }
        .task { await viewModel.send(.appeared) }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await viewModel.send(.tick)
            }
        }
        .onChange(of: router.pendingAction, initial: true) {
            if router.consume(.planMeal) {
                Task { await viewModel.send(.addMeal(viewModel.selectedDay, .dinner)) }
            }
        }
    }

    /// iPhone shows day sections; the Mac shows the week grid.
    private var isCompact: Bool { PlatformIdiom.current == .phone }

    private var header: PlanningHeader {
        PlanningHeader(
            subtitle: String(
                localized:
                    "planning.week-subtitle \(KodaFormat.weekNumber(viewModel.weekStart)) \(KodaFormat.monthName(viewModel.weekStart.adding(days: 3), locale: locale))"
            ),
            range: "\(KodaFormat.day(viewModel.weekStart, .dateTime.day(), locale: locale)) – "
                + KodaFormat.day(viewModel.weekStart.adding(days: 6), .dateTime.day().month(.wide), locale: locale),
            onPrevious: { Task { await viewModel.send(.previousWeek) } },
            onToday: { Task { await viewModel.send(.goToToday) } },
            onNext: { Task { await viewModel.send(.nextWeek) } }
        )
    }
}

/// Title and week navigation shared by both layouts.
struct PlanningHeader: View {
    let subtitle: String
    let range: String
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScreenHeader(subtitle: subtitle, title: String(localized: "tab.planning")) {
            HStack(spacing: KodaSpacing.xs) {
                WeekNavButton(systemImage: "chevron.left", labelKey: "planning.week.previous", action: onPrevious)
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                WeekNavButton(systemImage: "calendar", labelKey: "planning.week.today", action: onToday)
                    .keyboardShortcut("t", modifiers: .command)
                WeekNavButton(systemImage: "chevron.right", labelKey: "planning.week.next", action: onNext)
                    .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
    }
}

private struct WeekNavButton: View {
    let systemImage: String
    let labelKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(KodaColor.brandText)
                .frame(width: KodaSize.hitTarget - 4, height: KodaSize.hitTarget - 4)
                .background(KodaColor.surface, in: Circle())
                .overlay { Circle().strokeBorder(KodaColor.brand.opacity(0.18)) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(labelKey))
    }
}

/// iPhone: week strip, draft, day sections and the "Generar compra" button.
private struct PlanningCompactContent: View {
    @Bindable var viewModel: PlanningViewModel
    let header: PlanningHeader
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: KodaSpacing.l - 6) {
                    header
                    WeekStrip(days: stripDays, selected: viewModel.selectedDay) { day in
                        Task { await viewModel.send(.selectDay(day)) }
                        withAnimation { proxy.scrollTo(day, anchor: .top) }
                    }
                    ForEach(viewModel.drafts) { draft in
                        PlanningDraftCard(
                            draft: draft,
                            isDiscarding: viewModel.draftAction == .discarding(draft.id),
                            onReview: { router.navigate(to: .mealPlanDraft(id: draft.id), in: .planning) },
                            onDiscard: { Task { await viewModel.send(.discardDraft(draft)) } }
                        )
                    }
                    ForEach(viewModel.week?.days ?? []) { day in
                        PlanningDayCard(
                            day: day,
                            title: title(for: day.day),
                            slots: viewModel.visibleSlots,
                            slotTimes: viewModel.slotTimes,
                            isEaten: viewModel.isEaten,
                            onAdd: { slot in Task { await viewModel.send(.addMeal(day.day, slot)) } },
                            onEdit: { entry in Task { await viewModel.send(.editMeal(entry)) } },
                            onRemove: { entry in Task { await viewModel.send(.removeMeal(entry)) } }
                        )
                    }
                }
                .padding(.horizontal, KodaSpacing.l - 4)
                .padding(.top, KodaSpacing.s)
                .padding(.bottom, KodaSpacing.xl * 4)
            }
            .task(id: viewModel.week?.startDay) {
                // Open on the selected day (today), like the approved mockup.
                guard viewModel.week != nil else { return }
                proxy.scrollTo(viewModel.selectedDay, anchor: .top)
            }
            .safeAreaInset(edge: .bottom) {
                GenerateShoppingButton(cycle: viewModel.shoppingCycle) {
                    Task { await viewModel.send(.generateShopping) }
                }
                .padding(.leading, KodaSpacing.l - 4)
                .padding(.trailing, KodaSize.fab + KodaSpacing.l + KodaSpacing.xs)
                .padding(.bottom, KodaSpacing.s)
            }
        }
    }

    private var stripDays: [WeekStrip.Day] {
        (viewModel.week?.days ?? []).map { day in
            let main = [MealSlot.lunch, .dinner].filter { !day.meals(in: $0).isEmpty }.count
            return WeekStrip.Day(
                day: day.day,
                isToday: day.day == viewModel.today,
                fill: day.meals.isEmpty ? 0 : (main == 2 ? 2 : 1)
            )
        }
    }

    private func title(for day: LocalDay) -> String {
        let text = KodaFormat.weekdayAndDay(day, locale: locale).capitalizedFirst
        return day == viewModel.today ? String(localized: "planning.day.today \(text.lowercased())") : text
    }
}

/// "Generar compra · sáb 24 – vie 30".
struct GenerateShoppingButton: View {
    let cycle: ShoppingCycle
    let action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.s - 2) {
                Image(systemName: "bag")
                    .foregroundStyle(KodaColor.taupe)
                Text("planning.generate-shopping.range \(range)")
                    .font(KodaTypography.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(KodaColor.cream)
            .frame(maxWidth: .infinity, minHeight: KodaSize.fab - 4)
            .glassEffect(.regular.tint(KodaColor.onyx).interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("planning-generate-shopping")
    }

    private var range: String {
        "\(KodaFormat.shortDay(cycle.from, locale: locale)) – \(KodaFormat.shortDay(cycle.through, locale: locale))"
    }
}

/// Mac (and any regular width): the week grid.
private struct PlanningGridContent: View {
    @Bindable var viewModel: PlanningViewModel
    let header: PlanningHeader
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KodaSpacing.m) {
                header
                ForEach(viewModel.drafts) { draft in
                    PlanningDraftCard(
                        draft: draft,
                        isDiscarding: viewModel.draftAction == .discarding(draft.id),
                        onReview: { router.navigate(to: .mealPlanDraft(id: draft.id), in: .planning) },
                        onDiscard: { Task { await viewModel.send(.discardDraft(draft)) } }
                    )
                    .frame(maxWidth: KodaSize.readableWidth)
                }
                if let week = viewModel.week {
                    WeekGrid(
                        week: week,
                        slots: viewModel.visibleSlots,
                        today: viewModel.today,
                        nextEntryID: viewModel.nextEntryID,
                        isEaten: viewModel.isEaten,
                        onAdd: { day, slot in Task { await viewModel.send(.addMeal(day, slot)) } },
                        onEdit: { entry in Task { await viewModel.send(.editMeal(entry)) } },
                        onRemove: { entry in Task { await viewModel.send(.removeMeal(entry)) } },
                        onMove: { id, day, slot in
                            Task { await viewModel.send(.moveMeal(entryID: id, day: day, slot: slot)) }
                        }
                    )
                }
            }
            .padding(KodaSpacing.l)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Planning · iPhone") {
        PlanningPreviewFactory.makePlanningView()
            .kodaPreview()
    }

    #Preview("Planning · empty") {
        PlanningPreviewFactory.makePlanningView(container: PreviewContainer.empty)
            .kodaPreview()
    }

    #Preview("Planning · dark") {
        PlanningPreviewFactory.makePlanningView()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Planning · Mac", traits: .fixedLayout(width: 1280, height: 800)) {
        PlanningPreviewFactory.makePlanningView()
            .kodaPreview()
    }
#endif
