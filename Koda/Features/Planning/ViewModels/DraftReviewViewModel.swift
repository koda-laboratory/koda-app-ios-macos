import Foundation
import Observation

enum DraftReviewState: Sendable, Equatable {
    case loading
    case ready
    case accepting
    case discarding
    /// Accepted, discarded, or no longer pending (resolved on another device).
    case finished
}

enum DraftReviewIntent: Sendable {
    case appeared
    case accept
    case discard
}

/// Reviews a planning draft (usually prepared by Claude through the MCP): accept or discard on the server.
@MainActor
@Observable
final class DraftReviewViewModel: MVIViewModel {
    // MARK: - Properties

    let draftID: UUID
    private(set) var state = DraftReviewState.loading
    private(set) var draft: MealPlanDraft?
    var toast: Toast?

    @ObservationIgnored private let observePendingDrafts: any ObservePendingDraftsUseCase
    @ObservationIgnored private let acceptDraft: any AcceptDraftUseCase
    @ObservationIgnored private let discardDraft: any DiscardDraftUseCase
    @ObservationIgnored private var observation: Task<Void, Never>?

    // MARK: - Lifecycle

    init(
        draftID: UUID,
        observePendingDrafts: any ObservePendingDraftsUseCase,
        acceptDraft: any AcceptDraftUseCase,
        discardDraft: any DiscardDraftUseCase
    ) {
        self.draftID = draftID
        self.observePendingDrafts = observePendingDrafts
        self.acceptDraft = acceptDraft
        self.discardDraft = discardDraft
    }

    deinit {
        observation?.cancel()
    }

    // MARK: - Derived

    /// Draft meals grouped by day.
    var days: [DayPlan] {
        let entries = draft?.entries ?? []
        let byDay = Dictionary(grouping: entries, by: \.day)
        return byDay.keys.sorted().map { DayPlan(day: $0, meals: MealPlanEntry.ordered(byDay[$0] ?? [])) }
    }

    // MARK: - Intents

    func send(_ intent: DraftReviewIntent) async {
        switch intent {
        case .appeared:
            startObserving()
        case .accept:
            await resolve(accepting: true)
        case .discard:
            await resolve(accepting: false)
        }
    }

    // MARK: - Private Methods

    private func startObserving() {
        guard observation == nil else { return }
        let stream = observePendingDrafts.execute()
        let draftID = draftID
        observation = Task { [weak self] in
            for await drafts in stream {
                guard let self else { return }
                if let draft = drafts.first(where: { $0.id == draftID }) {
                    self.draft = draft
                    if self.state == .loading { self.state = .ready }
                } else if self.state == .loading || self.state == .ready {
                    self.state = .finished
                }
            }
        }
    }

    private func resolve(accepting: Bool) async {
        guard state == .ready else { return }
        state = accepting ? .accepting : .discarding
        do {
            if accepting {
                try await acceptDraft.execute(draftID: draftID)
            } else {
                try await discardDraft.execute(draftID: draftID)
            }
            state = .finished
        } catch {
            state = .ready
            toast = .error(error)
        }
    }
}
