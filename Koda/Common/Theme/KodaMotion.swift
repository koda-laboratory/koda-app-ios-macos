import SwiftUI

// MARK: - Motion

/// Motion tokens: short, purposeful animations on state changes (an item checked, a meal added or removed, a
/// section expanded). Every one goes through `kodaAnimation(_:value:)` or `KodaMotion.animation(_:reduceMotion:)`,
/// so Reduce Motion turns them off.
enum KodaMotion {
    /// List and card changes: rows that appear, disappear or move between sections.
    static let standard = Animation.snappy(duration: 0.3)
    /// Expanding and collapsing a section.
    static let disclosure = Animation.easeInOut(duration: 0.2)
    /// Hover and pressed feedback.
    static let hover = Animation.easeOut(duration: 0.15)

    /// `animation`, or `nil` with Reduce Motion on (for `withAnimation`).
    static func animation(_ animation: Animation = standard, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

private struct KodaAnimationModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(KodaMotion.animation(animation, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// Animates the changes caused by `value`, or applies them at once with Reduce Motion on.
    func kodaAnimation<Value: Equatable>(_ animation: Animation = KodaMotion.standard, value: Value) -> some View {
        modifier(KodaAnimationModifier(animation: animation, value: value))
    }
}
