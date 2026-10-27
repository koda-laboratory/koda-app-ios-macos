import SwiftUI

// MARK: - Detail Hero

/// Header of the recipe and product details. With a cover: the photo full-bleed under a scrim, the title and its tags.
/// Without one: `placeholder` (the signature gradient with the arcs or an emoji) and "Añadir portada".
struct DetailHero<Placeholder: View>: View {
    let title: String
    let tags: [String]
    let imagePath: String?
    var bucket = ImageBucket.recipes
    var addCoverIdentifier = "recipe-add-cover"
    var onAddCover: (() -> Void)?
    @ViewBuilder let placeholder: () -> Placeholder

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if imagePath != nil {
                RecipeImageView(path: imagePath, maxPixelSize: 1600, bucket: bucket) { placeholder() }
                KodaGradient.photoScrim
            } else {
                placeholder()
            }
            VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
                Text(verbatim: title)
                    .font(KodaTypography.display)
                    .foregroundStyle(KodaColor.cream)
                    .accessibilityAddTraits(.isHeader)
                if !tags.isEmpty {
                    FlowTags(tags: tags)
                }
                if imagePath == nil, let onAddCover {
                    AddCoverButton(action: onAddCover)
                        .accessibilityIdentifier(addCoverIdentifier)
                        .padding(.top, KodaSpacing.xxs)
                }
            }
            .padding(.horizontal, KodaSpacing.l - 4)
            .padding(.bottom, KodaSpacing.l + 2)
        }
        .frame(height: KodaSize.recipeHeroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

/// The signature gradient with the Koda arcs: the hero without a cover.
struct DetailHeroArcsBackground: View {
    var body: some View {
        ZStack {
            KodaGradient.signature
            KodaArcs(colors: [KodaColor.walnutDeep, KodaColor.walnut, KodaColor.taupe], aspectRatio: 300.0 / 260.0)
                .frame(width: 260)
                .opacity(0.55)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 40)
        }
    }
}

/// "Añadir portada": a translucent pill on the dark hero.
private struct AddCoverButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("recipe.photos.add-cover", systemImage: "camera")
                .font(KodaTypography.subheadline.weight(.bold))
                .foregroundStyle(KodaColor.cream)
                .padding(.horizontal, KodaSpacing.m)
                .frame(minHeight: KodaSize.hitTarget)
                .background(KodaColor.onyx.opacity(0.35), in: Capsule())
                .overlay(Capsule().strokeBorder(KodaColor.taupe.opacity(0.5)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Wrapping row of tags on the hero.
private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: KodaSpacing.xs - 2) {
                ForEach(tags, id: \.self) { TagView(text: $0, onDark: true) }
            }
            VStack(alignment: .leading, spacing: KodaSpacing.xs - 2) {
                HStack(spacing: KodaSpacing.xs - 2) {
                    ForEach(tags.prefix(3), id: \.self) { TagView(text: $0, onDark: true) }
                }
                HStack(spacing: KodaSpacing.xs - 2) {
                    ForEach(tags.dropFirst(3), id: \.self) { TagView(text: $0, onDark: true) }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Detail hero · no cover") {
        DetailHero(
            title: "Arroz a la cubana",
            tags: ["Comida", "45 min"],
            imagePath: nil,
            onAddCover: {},
            placeholder: DetailHeroArcsBackground.init
        )
        .kodaPreview()
    }

    #Preview("Detail hero · dark") {
        DetailHero(
            title: "Aguja de ternera",
            tags: ["Comida", "kg"],
            imagePath: nil,
            onAddCover: {},
            placeholder: DetailHeroArcsBackground.init
        )
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Detail hero · Mac", traits: .fixedLayout(width: 900, height: 400)) {
        DetailHero(
            title: "Arroz a la cubana",
            tags: ["Comida"],
            imagePath: nil,
            onAddCover: {},
            placeholder: DetailHeroArcsBackground.init
        )
        .kodaPreview()
    }
#endif
