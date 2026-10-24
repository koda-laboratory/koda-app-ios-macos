import SwiftUI

// MARK: - Feedback Event

/// A one-shot confirmation a ViewModel raises after a local write succeeds (added, removed, marked). The screen
/// plays it as a haptic with `feedbackHaptic(_:)`, so changes pulled from the other device never buzz.
struct FeedbackEvent: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        /// Something new: a product on the list, a meal planned, a favourite.
        case added
        /// Something gone: a row removed, a meal deleted or skipped.
        case removed
        /// A task done: a defrost resolved, a draft accepted.
        case completed
    }

    let kind: Kind
    /// Two events of the same kind in a row are still two changes.
    let id = UUID()

    init(_ kind: Kind) {
        self.kind = kind
    }

    var sensoryFeedback: SensoryFeedback {
        switch kind {
        case .added: .success
        case .removed: .impact(weight: .medium)
        case .completed: .success
        }
    }
}

extension View {
    /// Plays `event` as a haptic on iPhone (nothing on the Mac).
    func feedbackHaptic(_ event: FeedbackEvent?) -> some View {
        platformHaptic(trigger: event) { _, new in new?.sensoryFeedback }
    }
}
