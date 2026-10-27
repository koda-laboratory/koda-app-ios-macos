import SwiftUI

/// "A la compra": full-width inverse button of the product detail.
struct ProductShoppingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("recipe.action.shopping", systemImage: "bag.badge.plus")
                .font(KodaTypography.body.weight(.bold))
                .foregroundStyle(KodaColor.onInverse)
                .frame(maxWidth: .infinity, minHeight: KodaSize.fieldHeight + 8)
                .background(
                    KodaColor.inverse,
                    in: RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous)
                )
                .kodaHoverHighlight(cornerRadius: KodaRadius.medium)
                .contentShape(RoundedRectangle(cornerRadius: KodaRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("product-add-to-shopping")
    }
}

/// "Tiendas": where the household buys the product, as chips.
struct ProductStoresSection: View {
    let stores: [Store]

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            SectionHeader(titleKey: "product.stores")
            FlowLayout {
                ForEach(stores) { store in
                    Text(verbatim: store.name)
                        .font(KodaTypography.subheadline.weight(.bold))
                        .foregroundStyle(KodaColor.textPrimary)
                        .padding(.horizontal, KodaSpacing.s + 2)
                        .frame(minHeight: KodaSize.chipHeight)
                        .background(KodaColor.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(KodaColor.brand.opacity(0.2)))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Se usa en": the recipes that have the product as an ingredient, each one opening its detail.
struct ProductUsagesSection: View {
    let usages: [ProductRecipeUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            SectionHeader(titleKey: "product.used-in")
            VStack(spacing: 0) {
                ForEach(Array(usages.enumerated()), id: \.element.id) { index, usage in
                    if index > 0 {
                        Divider().overlay(KodaColor.background).padding(.horizontal, KodaSpacing.m)
                    }
                    NavigationLink(value: AppRoute.recipe(id: usage.recipeID)) {
                        UsageRow(usage: usage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("product-used-in-\(usage.recipeID)")
                }
            }
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
        }
    }
}

/// Initials tile, name, "500 g · 90 min" and a chevron.
private struct UsageRow: View {
    let usage: ProductRecipeUsage
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: KodaSpacing.s) {
            let palette = RecipeTilePalette(id: usage.recipeID)
            Text(verbatim: RecipeTilePalette.initials(of: usage.recipeName))
                .font(KodaTypography.subheadline.weight(.heavy))
                .foregroundStyle(palette.foreground)
                .padding(KodaSpacing.xxs)
                .frame(width: KodaSize.rowTile, height: KodaSize.rowTile, alignment: .bottomLeading)
                .background(palette.background, in: RoundedRectangle(cornerRadius: KodaRadius.small - 2))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: usage.recipeName)
                    .font(KodaTypography.body.weight(.bold))
                    .foregroundStyle(KodaColor.textPrimary)
                if !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(KodaTypography.footnote)
                        .foregroundStyle(KodaColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(KodaTypography.subheadline)
                .foregroundStyle(KodaColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, KodaSpacing.m)
        .padding(.vertical, KodaSpacing.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let quantity = KodaFormat.quantity(usage.quantity, unit: usage.unit, locale: locale)
        let minutes = usage.displayMinutes.map { String(localized: "recipe.minutes \($0)") }
        return KodaFormat.joined([quantity, minutes])
    }
}

/// "Notas": the product's notes, read-only (they are edited in the editor).
struct ProductNotesSection: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            SectionHeader(titleKey: "product.notes")
            Text(verbatim: notes)
                .font(KodaTypography.body)
                .foregroundStyle(KodaColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(KodaSpacing.m)
                .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous)
                        .strokeBorder(KodaColor.separator)
                )
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Product sections") {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KodaSpacing.l) {
                    ProductShoppingButton {}
                    ProductStoresSection(stores: ProductsPreviewFactory.stores)
                    ProductUsagesSection(usages: ProductsPreviewFactory.usages)
                    ProductNotesSection(notes: "La de Mercadona viene en bandeja de 600 g.")
                }
                .padding()
            }
        }
        .kodaPreview()
    }

    #Preview("Product sections · dark") {
        NavigationStack {
            VStack(alignment: .leading, spacing: KodaSpacing.l) {
                ProductStoresSection(stores: ProductsPreviewFactory.stores)
                ProductUsagesSection(usages: ProductsPreviewFactory.usages)
            }
            .padding()
        }
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Product sections · Mac", traits: .fixedLayout(width: 800, height: 600)) {
        NavigationStack {
            VStack(alignment: .leading, spacing: KodaSpacing.l) {
                ProductShoppingButton {}
                ProductStoresSection(stores: ProductsPreviewFactory.stores)
                ProductUsagesSection(usages: ProductsPreviewFactory.usages)
            }
            .padding()
        }
        .kodaPreview()
    }
#endif
