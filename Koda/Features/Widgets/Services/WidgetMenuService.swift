import Foundation

/// Keeps the widgets' snapshot in step with the data: observes the next days' meals, the shopping list and the
/// household settings and republishes it on every change, whether made on this device or arrived by sync.
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
    private let shoppingRepository: any ShoppingRepository
    private let meRepository: any MeRepository
    private let widgetMenuRepository: any WidgetMenuRepository
    private let clock: @Sendable () -> Date

    private var observation: Task<Void, Never>?
    private var observedFrom: LocalDay?
    private var household: HouseholdContext?
    private var entries: [MealPlanEntry] = []
    private var shopping: WidgetMenu.Shopping?
    private var lastPublished: WidgetMenu?

    init(
        planningRepository: any PlanningRepository,
        shoppingRepository: any ShoppingRepository,
        meRepository: any MeRepository,
        widgetMenuRepository: any WidgetMenuRepository,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.planningRepository = planningRepository
        self.shoppingRepository = shoppingRepository
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
        let shoppingEntries = shoppingRepository.observeEntries()
        observation = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await household in households { await self?.update(household: household) }
                }
                group.addTask {
                    for await entries in plan { await self?.update(entries: entries) }
                }
                group.addTask {
                    for await entries in shoppingEntries { await self?.update(shopping: Self.shopping(entries)) }
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
        shopping = nil
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

    private func update(shopping: WidgetMenu.Shopping) {
        self.shopping = shopping
        publish()
    }

    private func publish() {
        guard let household, let observedFrom else { return }
        var menu = Self.menu(
            entries: entries,
            from: observedFrom,
            days: Self.days,
            timeZone: household.household.timeZone,
            slotTimes: household.household.settings.slotTimes,
            slotTitle: { String(localized: $0.titleResource) }
        )
        menu.shopping = shopping
        guard menu != lastPublished else { return }
        lastPublished = menu
        widgetMenuRepository.publish(menu)
    }

    /// The pending products for the "Compra" widget: loose ones and those of recipe entries still being bought,
    /// each product once.
    static func shopping(_ entries: [ShoppingEntry], limit: Int = 8) -> WidgetMenu.Shopping {
        var names: [String] = []
        var seen: Set<String> = []
        func add(_ name: String) {
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            guard seen.insert(key).inserted else { return }
            names.append(name)
        }
        for entry in entries.sorted(by: { $0.position < $1.position }) {
            switch entry.kind {
            case .product, .text:
                if entry.status == .pending { add(entry.title) }
            case .recipe:
                guard entry.status != .have else { continue }
                for item in entry.items where item.status == .pending { add(item.productName) }
            }
        }
        return WidgetMenu.Shopping(pendingCount: names.count, items: Array(names.prefix(limit)))
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
