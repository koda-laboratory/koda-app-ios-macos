import SwiftUI

extension View {
    /// Haptic feedback on iPhone when `trigger` changes. Nothing on the Mac: a trackpad tick for list edits feels
    /// wrong there.
    func platformHaptic<Trigger: Equatable>(_ feedback: SensoryFeedback, trigger: Trigger) -> some View {
        #if os(iOS)
            sensoryFeedback(feedback, trigger: trigger)
        #else
            self
        #endif
    }

    /// Haptic feedback on iPhone when `trigger` changes and `condition(old, new)` holds. Nothing on the Mac.
    func platformHaptic<Trigger: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: Trigger,
        condition: @escaping (Trigger, Trigger) -> Bool
    ) -> some View {
        #if os(iOS)
            sensoryFeedback(feedback, trigger: trigger, condition: condition)
        #else
            self
        #endif
    }

    /// Haptic feedback on iPhone chosen from the change of `trigger` (`nil` plays nothing). Nothing on the Mac.
    func platformHaptic<Trigger: Equatable>(
        trigger: Trigger,
        _ feedback: @escaping (Trigger, Trigger) -> SensoryFeedback?
    ) -> some View {
        #if os(iOS)
            sensoryFeedback(trigger: trigger, feedback)
        #else
            self
        #endif
    }
}
