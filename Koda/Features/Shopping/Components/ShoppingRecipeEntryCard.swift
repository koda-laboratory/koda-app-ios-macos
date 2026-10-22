import SwiftUI

/// A recipe entry ("Arroz a la cubana · Lunes 26, comida · 2 por comprar · 1 congelado"), expandable to tick
/// its products one by one.
struct ShoppingRecipeEntryCard: View {
    let entry: ShoppingEntry
    let subtitle: String
    let isExpanded: Bool
    let rows: [ShoppingRow]
    let onToggleExpanded: () -> Void
    let onToggleHave: (ShoppingRow) -> Void
    let onToggleFrozen: (ShoppingRow) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleExpanded) {
                HStack(spacing: KodaSpacing.s) {
                    Image(systemName: "book.closed")
                        .foregroundStyle(KodaColor.taupe)
                        .frame(width: 40, height: 40)
                        .background(KodaColor.onyx, in: RoundedRectangle(cornerRadius: KodaRadius.small))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: entry.title)
                            .font(KodaTypography.body.weight(.bold))
                            .foregroundStyle(KodaColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: subtitle)
                            .font(KodaTypography.footnote)
                            .foregroundStyle(KodaColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.bold))
                        .foregroundStyle(KodaColor.brandText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, KodaSpacing.m)
                .padding(.vertical, KodaSpacing.s + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isExpanded ? "shopping.recipe.expanded" : "shopping.recipe.collapsed"))
            .accessibilityIdentifier("shopping-recipe-\(entry.id)")
            .contextMenu {
                Button("shopping.remove", systemImage: "trash", role: .destructive, action: onRemove)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Divider().overlay(KodaColor.chip)
                        ShoppingRowView(
                            row: row,
                            meta: row.quantityText,
                            compact: true,
                            onToggleHave: { onToggleHave(row) },
                            onToggleFrozen: { onToggleFrozen(row) }
                        )
                    }
                }
                .padding(.leading, KodaSpacing.xl + KodaSpacing.l + 4)
                .padding(.bottom, KodaSpacing.xs - 2)
            }
        }
        .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

/// "Compra del viernes 23 · Cubre del sáb 24 al vie 30 · cámbialo al generar · Planning".
struct ShoppingCycleCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.s) {
                Image(systemName: "calendar")
                    .foregroundStyle(KodaColor.taupe)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: title)
                        .font(KodaTypography.subheadline.weight(.bold))
                        .foregroundStyle(KodaColor.cream)
                    Text(verbatim: subtitle)
                        .font(KodaTypography.caption)
                        .foregroundStyle(KodaColor.taupe)
                }
                Spacer(minLength: 0)
                Text("tab.planning")
                    .font(KodaTypography.footnote.weight(.bold))
                    .foregroundStyle(KodaColor.taupe)
            }
            .padding(.horizontal, KodaSpacing.s + 2)
            .padding(.vertical, KodaSpacing.s)
            .background(KodaColor.onyx, in: RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shopping-cycle")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Recipe entry") {
        ShoppingRecipeEntryCard(
            entry: ShoppingPreviewFactory.recipeEntry,
            subtitle: "Lunes 26, comida · 2 por comprar",
            isExpanded: true,
            rows: ShoppingPreviewFactory.rows,
            onToggleExpanded: {},
            onToggleHave: { _ in },
            onToggleFrozen: { _ in },
            onRemove: {}
        )
        .padding()
        .kodaPreview()
    }

    #Preview("Recipe entry · dark") {
        VStack {
            ShoppingCycleCard(title: "Compra del viernes 23", subtitle: "Cubre del sáb 24 al vie 30") {}
            ShoppingRecipeEntryCard(
                entry: ShoppingPreviewFactory.recipeEntry,
                subtitle: "2 por comprar",
                isExpanded: false,
                rows: [],
                onToggleExpanded: {},
                onToggleHave: { _ in },
                onToggleFrozen: { _ in },
                onRemove: {}
            )
        }
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Recipe entry · Mac", traits: .fixedLayout(width: 700, height: 400)) {
        ShoppingCycleCard(title: "Compra del viernes 23", subtitle: "Cubre del sáb 24 al vie 30") {}
            .frame(width: 480)
            .kodaPreview()
    }
#endif
