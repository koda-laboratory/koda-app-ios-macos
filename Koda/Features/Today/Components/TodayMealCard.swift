import SwiftUI

/// A meal of today in its progress state: done ("Hecha"), the next one (highlighted, "Se marcará como cenada a
/// las 21:30", "Cambiar", "No lo comimos"), later, skipped or free text.
struct TodayMealCard: View {
    let meal: TodayProgress.Meal
    let detail: String
    let onChange: () -> Void
    let onSkip: () -> Void

    var body: some View {
        Group {
            if let recipeID = meal.entry.recipeID {
                NavigationLink(value: AppRoute.recipe(id: recipeID)) { card.kodaHoverHighlight() }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
        .contextMenu {
            Button("today.meal.change", systemImage: "arrow.triangle.2.circlepath", action: onChange)
            if meal.entry.isRecipe, meal.state != .skipped {
                Button("today.meal.skip", systemImage: "xmark.circle", role: .destructive, action: onSkip)
            }
        }
        // The context menu is hard to reach with VoiceOver: the same actions as rotor actions.
        .accessibilityAction(named: Text("today.meal.change"), onChange)
        .accessibilityActions {
            if meal.entry.isRecipe, meal.state != .skipped, meal.state != .next {
                Button("today.meal.skip", action: onSkip)
            }
        }
        .accessibilityIdentifier("today-meal-\(meal.entry.slot.rawValue)")
    }

    private var card: some View {
        MealCard(
            eyebrow: eyebrow,
            title: meal.entry.title,
            detail: detail,
            systemImage: meal.entry.slot.systemImage,
            badge: badge,
            isHighlighted: meal.state == .next,
            isDimmed: meal.state == .skipped
        ) {
            if meal.state == .next {
                VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
                    HStack(spacing: KodaSpacing.s - 2) {
                        Text(meal.entry.slot.willMarkKey(time: meal.time.description))
                            .font(KodaTypography.footnote)
                            .foregroundStyle(KodaColor.textSecondary)
                        Spacer(minLength: KodaSpacing.xs)
                        Button("today.meal.change", action: onChange)
                            .buttonStyle(.kodaPill(.outline))
                            .accessibilityIdentifier("today-meal-change")
                    }
                    Button("today.meal.skip", action: onSkip)
                        .font(KodaTypography.footnote.weight(.semibold))
                        .foregroundStyle(KodaColor.textTertiary)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("today-meal-skip")
                }
            }
        }
    }

    private var eyebrow: LocalizedStringKey {
        meal.state == .next
            ? "today.meal.next-eyebrow \(String(localized: meal.entry.slot.titleResource))"
            : meal.entry.slot.titleKey
    }

    private var badge: LocalizedStringKey? {
        switch meal.state {
        case .done: "today.meal.done"
        case .skipped: "today.meal.skipped"
        case .next, .later, .notCounted: nil
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Today meal cards") {
        NavigationStack {
            ScrollView {
                VStack(spacing: KodaSpacing.s) {
                    ForEach(TodayPreviewFactory.progress(done: 1).meals) { meal in
                        TodayMealCard(meal: meal, detail: "\(meal.time) · 30 min", onChange: {}, onSkip: {})
                    }
                }
                .padding()
            }
        }
        .kodaPreview()
    }

    #Preview("Today meal cards · dark") {
        NavigationStack {
            VStack(spacing: KodaSpacing.s) {
                ForEach(TodayPreviewFactory.progress(done: 2).meals) { meal in
                    TodayMealCard(meal: meal, detail: "\(meal.time)", onChange: {}, onSkip: {})
                }
            }
            .padding()
        }
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Today meal cards · Mac", traits: .fixedLayout(width: 800, height: 500)) {
        NavigationStack {
            VStack(spacing: KodaSpacing.s) {
                ForEach(TodayPreviewFactory.progress(done: 0).meals) { meal in
                    TodayMealCard(meal: meal, detail: "\(meal.time)", onChange: {}, onSkip: {})
                }
            }
            .frame(width: 520)
        }
        .kodaPreview()
    }
#endif
