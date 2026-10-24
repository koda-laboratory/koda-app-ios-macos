import SwiftUI

/// "PARA LA COMPRA · 9 pendientes · Mercadona 5 · Aldi 3". Opens the shopping list.
struct ShoppingSummaryCard: View {
    let pendingCount: Int
    let stores: [(store: String, count: Int)]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.m) {
                VStack(alignment: .leading, spacing: KodaSpacing.xxs) {
                    Text("today.shopping.eyebrow").kodaEyebrow()
                    HStack(alignment: .firstTextBaseline, spacing: KodaSpacing.xs - 2) {
                        Text(verbatim: "\(pendingCount)")
                            .font(KodaTypography.title)
                            .foregroundStyle(KodaColor.textPrimary)
                        Text("today.shopping.pending")
                            .font(KodaTypography.headline)
                            .foregroundStyle(KodaColor.textSecondary)
                    }
                    if !stores.isEmpty {
                        Text(verbatim: stores.prefix(3).map { "\($0.store) \($0.count)" }.joined(separator: " · "))
                            .font(KodaTypography.footnote)
                            .foregroundStyle(KodaColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(KodaColor.brandText)
                    .accessibilityHidden(true)
            }
            .padding(KodaSpacing.m)
            .kodaCardBackground()
            .kodaHoverHighlight()
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today-shopping-summary")
    }
}

/// "Hace 3 semanas que no coméis Gnocchi… · Añadir al planning".
struct SuggestionCard: View {
    let recipeName: String
    let weeks: Int
    let action: () -> Void

    private var weeksText: String { String(localized: "common.weeks \(weeks)") }

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            Text("today.suggestion.message \(weeksText) \(recipeName)")
                .font(KodaTypography.body)
                .foregroundStyle(KodaColor.textPrimary)
            Button("today.suggestion.plan", action: action)
                .buttonStyle(.kodaPill(.inverse))
                .accessibilityIdentifier("suggestion-plan")
        }
        .padding(KodaSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KodaColor.accentSoft, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Summary cards") {
        VStack(spacing: KodaSpacing.m) {
            ShoppingSummaryCard(pendingCount: 9, stores: [("Mercadona", 5), ("Aldi", 3), ("Chino", 1)]) {}
            SuggestionCard(recipeName: "Gnocchi cabrales con espinacas", weeks: 3) {}
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Summary cards · dark") {
        VStack(spacing: KodaSpacing.m) {
            ShoppingSummaryCard(pendingCount: 0, stores: []) {}
            SuggestionCard(recipeName: "Bacalao al pil pil", weeks: 5) {}
        }
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Summary cards · Mac", traits: .fixedLayout(width: 800, height: 400)) {
        ShoppingSummaryCard(pendingCount: 9, stores: [("Mercadona", 5)]) {}
            .frame(width: 520)
            .kodaPreview()
    }
#endif
