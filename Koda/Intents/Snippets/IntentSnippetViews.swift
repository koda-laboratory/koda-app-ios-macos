import AppIntents
import SwiftUI

/// One meal line of the "Hoy" card.
struct SnippetMeal: Sendable, Equatable {
    let slotTitle: String
    let title: String
    let time: String
}

/// The Siri / Shortcuts card of `TodayMealsIntent`.
struct TodayMealsSnippetView: View {
    let meals: [SnippetMeal]

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            if meals.isEmpty {
                Text("intent.today.nothing")
                    .font(KodaTypography.body)
                    .foregroundStyle(KodaColor.textSecondary)
            }
            ForEach(Array(meals.enumerated()), id: \.offset) { _, meal in
                HStack(alignment: .firstTextBaseline, spacing: KodaSpacing.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "\(meal.slotTitle.uppercased()) · \(meal.time)")
                            .kodaEyebrow()
                        Text(verbatim: meal.title)
                            .font(KodaTypography.headline)
                            .foregroundStyle(KodaColor.textPrimary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(KodaSpacing.m)
    }
}

/// The interactive Siri / Shortcuts card of `ShowShoppingListIntent`: each row ticks itself.
struct ShoppingListSnippetView: View {
    let rows: [ShoppingSnippetRow]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.xs) {
            if rows.isEmpty {
                Text("intent.show-shopping.empty")
                    .font(KodaTypography.body)
                    .foregroundStyle(KodaColor.textSecondary)
            }
            ForEach(rows) { row in
                Button(intent: MarkShoppingRowAsHaveIntent(row: row)) {
                    HStack(spacing: KodaSpacing.s) {
                        Image(systemName: "circle")
                            .foregroundStyle(KodaColor.taupe)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: row.title)
                                .font(KodaTypography.body.weight(.semibold))
                                .foregroundStyle(KodaColor.textPrimary)
                            if let detail = row.detail {
                                Text(verbatim: detail)
                                    .font(KodaTypography.caption)
                                    .foregroundStyle(KodaColor.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if total > rows.count {
                Text("intent.show-shopping.more \(total - rows.count)")
                    .font(KodaTypography.caption)
                    .foregroundStyle(KodaColor.textSecondary)
            }
        }
        .padding(KodaSpacing.m)
    }
}
