import SwiftUI

// MARK: - Meal Card

/// A meal of the day: icon tile, eyebrow ("CENA · LA SIGUIENTE"), title, details and a trailing badge, with an
/// optional footer for actions. The highlighted card is the next meal.
struct MealCard<Footer: View>: View {
    let eyebrow: LocalizedStringKey
    let title: String
    let detail: String
    let systemImage: String
    var badge: LocalizedStringKey?
    var isHighlighted = false
    var isDimmed = false
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            HStack(spacing: KodaSpacing.s) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isHighlighted ? KodaColor.taupe : KodaColor.brandText)
                    .frame(width: KodaSize.mealTile, height: KodaSize.mealTile)
                    .background(
                        isHighlighted ? KodaColor.onyx : KodaColor.chip,
                        in: RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: KodaSpacing.xxs) {
                    Text(eyebrow).kodaEyebrow(color: isHighlighted ? KodaColor.brandText : KodaColor.textTertiary)
                    Text(verbatim: title)
                        .font(KodaTypography.cardTitle)
                        .strikethrough(isDimmed)
                        .foregroundStyle(isDimmed ? KodaColor.textSecondary : KodaColor.textPrimary)
                    if !detail.isEmpty {
                        Text(verbatim: detail)
                            .font(KodaTypography.footnote)
                            .foregroundStyle(KodaColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(KodaTypography.eyebrow)
                        .foregroundStyle(KodaColor.brandText)
                        .padding(.horizontal, KodaSpacing.xs)
                        .padding(.vertical, KodaSpacing.xxs + 2)
                        .background(KodaColor.chip, in: Capsule())
                }
            }
            footer()
        }
        .padding(KodaSpacing.s + 2)
        .kodaCardBackground(highlight: isHighlighted ? KodaColor.brand : nil)
        .accessibilityElement(children: .contain)
    }
}

extension MealCard where Footer == EmptyView {
    init(
        eyebrow: LocalizedStringKey,
        title: String,
        detail: String,
        systemImage: String,
        badge: LocalizedStringKey? = nil,
        isDimmed: Bool = false
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            detail: detail,
            systemImage: systemImage,
            badge: badge,
            isHighlighted: false,
            isDimmed: isDimmed
        ) { EmptyView() }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Meal card") {
        VStack(spacing: KodaSpacing.s) {
            MealCard(
                eyebrow: "slot.lunch",
                title: "Curry de garbanzos",
                detail: "14:30 · 40 min",
                systemImage: "fork.knife",
                badge: "today.meal.done"
            )
            MealCard(
                eyebrow: "slot.dinner",
                title: "Ensalada César",
                detail: "21:30 · 30 min",
                systemImage: "moon.stars",
                isHighlighted: true
            ) {
                Button("today.meal.change") {}.buttonStyle(.kodaPill(.outline))
            }
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Meal card · dark") {
        MealCard(eyebrow: "slot.dinner", title: "Ensalada César", detail: "21:30", systemImage: "moon.stars")
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Meal card · Mac", traits: .fixedLayout(width: 700, height: 300)) {
        MealCard(eyebrow: "slot.dinner", title: "Ensalada César", detail: "21:30", systemImage: "moon.stars")
            .frame(width: 460)
            .kodaPreview()
    }
#endif
