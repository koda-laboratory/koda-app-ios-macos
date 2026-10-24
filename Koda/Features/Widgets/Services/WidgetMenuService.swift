import Foundation

/// Keeps the widgets' menu in step with the plan: observes the next days' meals and the household settings and
/// republishes the snapshot on every change, whether it was made on this device or arrived by sync.
protocol WidgetMenuService: Sendable {
    /// Starts (or restarts from today, after a day change) the observation. Idempotent within a day.
    func start() async
    /// Stops observing and clears the widgets (sign-out).
    func stopAndClear() async
}

actor WidgetMenuServiceImpl: WidgetMenuService {
    /// Days covered from today, so the widget stays useful without opening the app.
    static let days = 8

    private let planningRepository: any PlanningRepository
    private let meRepository: any MeRepository
    private let widgetMenuRepository: any WidgetMenuRepository
    private let clock: @Sendable () -> Date

    private var observation: Task<Void, Never>?
    private var observedFrom: LocalDay?
    private var household: HouseholdContext?
    private var entries: [MealPlanEntry] = []
    private var lastPublished: WidgetMenu?

    init(
        planningRepository: any PlanningRepository,
        meRepository: any MeRepository,
        widgetMenuRepository: any WidgetMenuRepository,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.planningRepository = planningRepository
        self.meRepository = meRepository
        self.widgetMenuRepository = widgetMenuRepository
        self.clock = clock
    }

    func start() {
        let today = LocalDay.today(in: household?.household.timeZone ?? .household, now: clock())
        guard observation == nil || observedFrom != today else { return }
        observation?.cancel()
        observedFrom = today
        let households = meRepository.observe()
        let plan = planningRepository.observeEntries(from: today, through: today.adding(days: Self.days - 1))
        observation = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await household in households { await self?.update(household: household) }
                }
                group.addTask {
                    for await entries in plan { await self?.update(entries: entries) }
                }
            }
        }
    }

    func stopAndClear() {
        observation?.cancel()
        observation = nil
        observedFrom = nil
        lastPublished = nil
        entries = []
        widgetMenuRepository.clear()
    }

    // MARK: - Private Methods

    private func update(household: HouseholdContext?) {
        self.household = household
        publish()
    }

    private func update(entries: [MealPlanEntry]) {
        self.entries = entries
        publish()
    }

    private func publish() {
        guard let household, let observedFrom else { return }
        let menu = Self.menu(
            entries: entries,
            from: observedFrom,
            days: Self.days,
            timeZone: household.household.timeZone,
            slotTimes: household.household.settings.slotTimes,
            slotTitle: { String(localized: $0.titleResource) }
        )
        guard menu != lastPublished else { return }
        lastPublished = menu
        widgetMenuRepository.publish(menu)
    }

    /// The snapshot for `days` days from `day`: planned meals in slot and time order, without draft proposals
    /// and meals marked as not eaten.
    static func menu(
        entries: [MealPlanEntry],
        from day: LocalDay,
        days: Int,
        timeZone: TimeZone,
        slotTimes: SlotTimes,
        slotTitle: (MealSlot) -> String
    ) -> WidgetMenu {
        let byDay = Dictionary(grouping: entries.filter { $0.draftID == nil && !$0.isSkipped }, by: \.day)
        let widgetDays = (0..<days).map { offset in
            let current = day.adding(days: offset)
            let meals = MealPlanEntry.ordered(byDay[current] ?? [])
                .map { entry in
                    WidgetMenu.Meal(
                        slotTitle: slotTitle(entry.slot),
                        title: entry.title,
                        minutes: entry.time(using: slotTimes).minutesSinceMidnight,
                        isRecipe: entry.isRecipe
                    )
                }
                .sorted { $0.minutes < $1.minutes }
            return WidgetMenu.Day(year: current.year, month: current.month, day: current.day, meals: meals)
        }
        return WidgetMenu(timeZoneIdentifier: timeZone.identifier, days: widgetDays)
    }
}
