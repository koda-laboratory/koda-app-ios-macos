import SwiftUI

/// Product detail header (`DetailHero`, approved mockup "Detalle de producto"): the cover photo, or the signature
/// gradient with the product emoji very large on the right (the Koda arcs without an emoji). Tags: category and
/// default unit.
struct ProductHero: View {
    let product: Product
    var onAddCover: (() -> Void)?

    var body: some View {
        DetailHero(
            title: product.name,
            tags: tags,
            imagePath: product.imagePath,
            bucket: .products,
            addCoverIdentifier: "product-add-cover",
            onAddCover: onAddCover
        ) {
            if let emoji = product.emoji, !emoji.isEmpty {
                EmojiBackground(emoji: emoji)
            } else {
                DetailHeroArcsBackground()
            }
        }
    }

    private var tags: [String] {
        [String(localized: product.category.titleResource), product.defaultUnit].compactMap { $0 }.filter {
            !$0.isEmpty
        }
    }
}

/// The signature gradient with the emoji bleeding off the top-right corner.
private struct EmojiBackground: View {
    let emoji: String

    var body: some View {
        ZStack {
            KodaGradient.signature
            Text(verbatim: emoji)
                .font(KodaTypography.heroEmoji)
                .rotationEffect(.degrees(-12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, KodaSpacing.xl * 2)
                .offset(x: KodaSpacing.l)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Product hero · emoji") {
        ProductHero(product: ProductsPreviewFactory.product, onAddCover: {})
            .kodaPreview()
    }

    #Preview("Product hero · no emoji · dark") {
        ProductHero(product: ProductsPreviewFactory.productWithoutEmoji, onAddCover: {})
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Product hero · Mac", traits: .fixedLayout(width: 900, height: 400)) {
        ProductHero(product: ProductsPreviewFactory.product, onAddCover: {})
            .kodaPreview()
    }
#endif
