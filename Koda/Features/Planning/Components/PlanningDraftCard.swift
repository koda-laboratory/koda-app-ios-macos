import SwiftUI

/// Claude's pending draft: "Borrador para la semana que viene · Revisar borrador · Descartar".
struct PlanningDraftCard: View {
    let draft: MealPlanDraft
    let isDiscarding: Bool
    let onReview: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            HStack(spacing: KodaSpacing.s - 2) {
                Image(systemName: "sparkles")
                    .foregroundStyle(KodaColor.taupe)
                    .accessibilityHidden(true)
                Text("planning.draft.title \(draft.entries.count)")
                    .font(KodaTypography.subheadline.weight(.bold))
            }
            if let rationale = draft.rationale, !rationale.isEmpty {
                Text(verbatim: rationale)
                    .font(KodaTypography.callout)
                    .foregroundStyle(KodaColor.taupeLight)
            }
            HStack(spacing: KodaSpacing.s - 2) {
                Button("planning.draft.review", action: onReview)
                    .buttonStyle(.kodaPill(.accent))
                    .accessibilityIdentifier("draft-review")
                Button(action: onDiscard) {
                    if isDiscarding {
                        ProgressView().tint(KodaColor.cream)
                    } else {
                        Text("planning.draft.discard")
                    }
                }
                .font(KodaTypography.subheadline.weight(.semibold))
                .foregroundStyle(KodaColor.cream)
                .padding(.horizontal, KodaSpacing.m)
                .frame(minHeight: KodaSize.hitTarget - KodaSpacing.xxs)
                .overlay { Capsule().strokeBorder(KodaColor.taupe.opacity(0.5)) }
                .buttonStyle(.plain)
                .disabled(isDiscarding)
            }
        }
        .foregroundStyle(KodaColor.cream)
        .padding(KodaSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KodaGradient.signature, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Draft card") {
        PlanningDraftCard(draft: PlanningPreviewFactory.draft, isDiscarding: false, onReview: {}, onDiscard: {})
            .padding()
            .kodaPreview()
    }

    #Preview("Draft card · dark") {
        PlanningDraftCard(draft: PlanningPreviewFactory.draft, isDiscarding: true, onReview: {}, onDiscard: {})
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Draft card · Mac", traits: .fixedLayout(width: 800, height: 300)) {
        PlanningDraftCard(draft: PlanningPreviewFactory.draft, isDiscarding: false, onReview: {}, onDiscard: {})
            .frame(width: 520)
            .kodaPreview()
    }
#endif
