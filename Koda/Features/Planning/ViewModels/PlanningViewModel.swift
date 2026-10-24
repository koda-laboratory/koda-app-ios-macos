import Foundation
import Observation

enum PlanningState: Sendable, Equatable {
    case loading
    case ready
}

enum PlanningDraftActionState: Sendable, Equatable {
    case idle
    case discarding(UUID)
}

enum PlanningSheet: Sendable, Equatable, Identifiable {
    case planMeal(PlanMealRequest)
    case generateShopping

    var id: String {
        switch self {
        case .planMeal(let request): "plan-\(request.id)"
        case .generateShopping: "generate-shopping"
        }
    }
}

enum PlanningIntent: Sendable {
    case appeared
    case tick
    case previousWeek
    case nextWeek
    case goToToday
    case selectDay(LocalDay)
    case addMeal(LocalDay, MealSlot)
    case editMeal(MealPlanEntry)
    case removeMeal(MealPlanEntry)
    /// Drag and drop between cells (Mac grid) or "Mover a…".
    case moveMeal(entryID: UUID, day: LocalDay, slot: MealSlot)
    case generateShopping
    case discardDraft(MealPlanDraft)
    case dismissSheet
}

/// Planning: the week (Monday–Sunday) with its slots, drafts, moving meals and "Generar compra".
@MainActor
@Observable
final class PlanningViewModel: MVIViewModel {
    // MARK: - Properties

    private(set) var state = PlanningState.loading
    private(set) var draftAction = PlanningDraftActionState.idle
    private(set) var week: WeekPlan?
    private(set) var weekStart: LocalDay
    private(set) var drafts: [MealPlanDraft] = []
    private(set) var household: HouseholdContext?
    private(set) var now: Date
    var selectedDay: LocalDay
    var presentedSheet: PlanningSheet?
    var toast: Toast?
    private(set) var feedback: FeedbackEvent?

    /// The use cases Planning depends on.
    struct UseCases {
        let observeWeekPlan: any ObserveWeekPlanUseCase
        let observePendingDrafts: any ObservePendingDraftsUseCase
        let observeHousehold: any ObserveHouseholdUseCase
        let updatePlannedMeal: any UpdatePlannedMealUseCase
        let removePlannedMeal: any RemovePlannedMealUseCase
        let discardDraft: any DiscardDraftUseCase
    }

    @ObservationIgnored private let useCases: UseCases
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var observations: [Task<Void, Never>]?
    @ObservationIgnored private var weekObservation: Task<Void, Never>?

    // MARK: - Lifecycle

    init(useCases: UseCases, clock: @escaping @Sendable () -> Date = { .now }) {
        self.useCases = useCases
        self.clock = clock
        let now = clock()
        let today = LocalDay.today(now: now)
        self.now = now
        self.weekStart = today.startOfWeek
        self.selectedDay = today
    }

    deinit {
        observations?.forEach { $0.cancel() }
        weekObservation?.cancel()
    }

    // MARK: - Derived

    var timeZone: TimeZone { household?.household.timeZone ?? .household }
    var today: LocalDay { LocalDay.today(in: timeZone, now: now) }
    var slotTimes: SlotTimes { household?.household.settings.slotTimes ?? .default }
    var shoppingCycle: ShoppingCycle {
        ShoppingCycle(today: today, shoppingWeekday: household?.household.settings.shoppingWeekday ?? 5)
    }

    /// Slots shown as rows: breakfast, lunch and dinner, plus snack when the week has one.
    var visibleSlots: [MealSlot] {
        let hasSnack = week?.days.contains { !$0.meals(in: .snack).isEmpty } ?? false
        return hasSnack ? MealSlot.allCases : [.breakfast, .lunch, .dinner]
    }

    func isEaten(_ entry: MealPlanEntry) -> Bool {
        entry.isEaten(now: now, slotTimes: slotTimes, timeZone: timeZone)
    }

    /// The first meal from now on that is not eaten yet ("AHORA TOCA" in the Mac grid).
    var nextEntryID: UUID? {
        let upcoming = (week?.days ?? []).flatMap(\.meals).filter { $0.isRecipe && !$0.isSkipped && !isEaten($0) }
        return upcoming.min { lhs, rhs in
            lhs.time(using: slotTimes).date(on: lhs.day, in: timeZone)
                < rhs.time(using: slotTimes).date(on: rhs.day, in: timeZone)
        }?.id
    }

    // MARK: - Intents

    func send(_ intent: PlanningIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .tick:
            now = clock()
        case .previousWeek:
            showWeek(weekStart.adding(days: -7))
        case .nextWeek:
            showWeek(weekStart.adding(days: 7))
        case .goToToday:
            selectedDay = today
            showWeek(today.startOfWeek)
        case .selectDay(let day):
            selectedDay = day
        case .addMeal(let day, let slot):
            presentedSheet = .planMeal(.new(day: day, slot: slot, recipeID: nil))
        case .editMeal(let entry):
            presentedSheet = .planMeal(.edit(entry))
        case .removeMeal(let entry):
            await remove(entry)
        case .moveMeal(let entryID, let day, let slot):
            await move(entryID: entryID, to: day, slot: slot)
        case .generateShopping:
            presentedSheet = .generateShopping
        case .discardDraft(let draft):
            await discard(draft)
        case .dismissSheet:
            presentedSheet = nil
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observations == nil else { return }
        let drafts = useCases.observePendingDrafts.execute()
        let households = useCases.observeHousehold.execute()
        observations = [
            Task { [weak self] in
                for await pending in drafts { self?.drafts = pending }
            },
            Task { [weak self] in
                for await household in households { self?.household = household }
            },
        ]
        observeWeek()
    }

    private func showWeek(_ start: LocalDay) {
        guard start != weekStart || weekObservation == nil else { return }
        weekStart = start
        if !(start...start.adding(days: 6)).contains(selectedDay) {
            selectedDay = (start...start.adding(days: 6)).contains(today) ? today : start
        }
        observeWeek()
    }

    private func observeWeek() {
        weekObservation?.cancel()
        let stream = useCases.observeWeekPlan.execute(containing: weekStart)
        weekObservation = Task { [weak self] in
            for await week in stream {
                self?.week = week
                self?.state = .ready
            }
        }
    }

    private func remove(_ entry: MealPlanEntry) async {
        do {
            try await useCases.removePlannedMeal.execute(entryID: entry.id)
            feedback = FeedbackEvent(.removed)
        } catch {
            toast = .error(error)
        }
    }

    private func move(entryID: UUID, to day: LocalDay, slot: MealSlot) async {
        guard let entry = week?.days.flatMap(\.meals).first(where: { $0.id == entryID }) else { return }
        guard entry.day != day || entry.slot != slot else { return }
        do {
            try await useCases.updatePlannedMeal.execute(
                entryID: entryID,
                MealPlanEntryUpdate(
                    day: day,
                    slot: slot,
                    recipeID: entry.recipeID,
                    freeText: entry.freeText,
                    servings: entry.servings,
                    scheduledTime: entry.scheduledTime
                )
            )
        } catch {
            toast = .error(error)
        }
    }

    private func discard(_ draft: MealPlanDraft) async {
        guard draftAction == .idle else { return }
        draftAction = .discarding(draft.id)
        do {
            try await useCases.discardDraft.execute(draftID: draft.id)
            feedback = FeedbackEvent(.removed)
            toast = Toast(messageKey: "planning.draft.discarded")
        } catch {
            toast = .error(error)
        }
        draftAction = .idle
    }
}
