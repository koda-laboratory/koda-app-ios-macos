import SwiftUI

/// A recipe entry ("Arroz a la cubana · Lunes 26, comida · 2 por comprar · 1 congelado"), expandable to tick
/// its products one by one. Also the "En varias recetas" card, whose rows show the recipes that need them.
struct ShoppingRecipeEntryCard: View {
    let title: String
    let subtitle: String
    var systemImage = "book.closed"
    let isExpanded: Bool
    let rows: [ShoppingRow]
    /// Rows show their recipes under the name instead of the quantity alone (the shared card).
    var showsRecipes = false
    let onToggleExpanded: () -> Void
    let onToggleHave: (ShoppingRow) -> Void
    let onToggleFrozen: (ShoppingRow) -> Void
    /// `nil` when the card cannot be removed as a whole.
    var onRemove: (() -> Void)?

    private var canExpand: Bool { !rows.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if canExpand { onToggleExpanded() }
            } label: {
                HStack(spacing: KodaSpacing.s) {
                    Image(systemName: systemImage)
                        .foregroundStyle(KodaColor.taupe)
                        .frame(width: 40, height: 40)
                        .background(KodaColor.onyx, in: RoundedRectangle(cornerRadius: KodaRadius.small))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: title)
                            .font(KodaTypography.body.weight(.bold))
                            .foregroundStyle(KodaColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: subtitle)
                            .font(KodaTypography.footnote)
                            .foregroundStyle(KodaColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if canExpand {
                        Image(systemName: "chevron.down")
                            .font(.body.weight(.bold))
                            .foregroundStyle(KodaColor.brandText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    } else if let onRemove {
                        // Nothing to expand (all its products are in "En varias recetas"): remove it right here.
                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(KodaColor.error)
                                .frame(width: KodaSize.hitTarget, height: KodaSize.hitTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("shopping.remove"))
                    }
                }
                .padding(.horizontal, KodaSpacing.m)
                .padding(.vertical, KodaSpacing.s + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                canExpand
                    ? Text(isExpanded ? "shopping.recipe.expanded" : "shopping.recipe.collapsed") : Text(verbatim: "")
            )
            .contextMenu {
                if let onRemove {
                    Button("shopping.remove", systemImage: "trash", role: .destructive, action: onRemove)
                }
            }
            .accessibilityActions {
                if let onRemove {
                    Button("shopping.remove", action: onRemove)
                }
            }

            if isExpanded, canExpand {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Divider().overlay(KodaColor.chip)
                        ShoppingRowView(
                            row: row,
                            meta: showsRecipes
                                ? KodaFormat.joined([row.recipeTitle, row.quantityText]) : row.quantityText,
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
        .kodaAnimation(KodaMotion.disclosure, value: isExpanded)
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
            // Onyx on the onyx dark background needs an edge.
            .overlay {
                RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous).strokeBorder(KodaColor.separator)
            }
            .kodaHoverHighlight(cornerRadius: KodaRadius.tile)
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
            title: ShoppingPreviewFactory.recipeEntry.title,
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
                title: "En varias recetas",
                subtitle: "2 por comprar",
                systemImage: "square.stack",
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
