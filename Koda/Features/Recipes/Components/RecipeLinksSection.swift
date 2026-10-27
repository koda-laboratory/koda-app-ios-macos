import SwiftUI

/// "Vídeos": the recipe's video links (TikTok, Instagram reels, YouTube shorts) with "+ Añadir enlace". Tapping a
/// row opens the link (universal links open the platform's app); the context menu removes it. Without links, a
/// compact dashed hint.
struct RecipeLinksSection: View {
    let links: [RecipeLink]
    let onAdd: () -> Void
    let onRemove: (RecipeLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            SectionHeader(titleKey: "recipe.links", actionKey: "recipe.links.add", action: onAdd)
                .accessibilityIdentifier("recipe-links-add")
            if links.isEmpty {
                EmptyLinksCard(action: onAdd)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                        if index > 0 {
                            Divider().overlay(KodaColor.background).padding(.horizontal, KodaSpacing.m)
                        }
                        RecipeLinkRow(link: link, onRemove: { onRemove(link) })
                    }
                }
                .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            }
        }
    }
}

/// Tile, title, "@account · se abre en TikTok" and ↗.
private struct RecipeLinkRow: View {
    let link: RecipeLink
    let onRemove: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        let presentation = RecipeLinkPresentation(info: link.info)
        Button {
            openURL(link.url)
        } label: {
            HStack(spacing: KodaSpacing.s) {
                RecipeLinkTile(presentation: presentation)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: presentation.title)
                        .font(KodaTypography.body.weight(.bold))
                        .foregroundStyle(KodaColor.textPrimary)
                    Text(verbatim: presentation.subtitle)
                        .font(KodaTypography.footnote)
                        .foregroundStyle(KodaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(KodaTypography.body.weight(.semibold))
                    .foregroundStyle(KodaColor.textPrimary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, KodaSpacing.m)
            .padding(.vertical, KodaSpacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier("recipe-link-\(link.id)")
        .contextMenu {
            Button("recipe.links.remove", systemImage: "trash", role: .destructive, action: onRemove)
        }
        .accessibilityAction(named: Text("recipe.links.remove"), onRemove)
    }
}

/// "Añade el enlace de un TikTok, reel o short…": the section's empty state.
private struct EmptyLinksCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.s) {
                Image(systemName: "play.rectangle")
                    .font(.title3)
                    .foregroundStyle(KodaColor.brandText)
                    .accessibilityHidden(true)
                Text("recipe.links.empty")
                    .font(KodaTypography.footnote)
                    .foregroundStyle(KodaColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(KodaSpacing.m)
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous)
                    .strokeBorder(KodaColor.brandText.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recipe-links-empty")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Links · filled") {
        RecipeLinksSection(links: RecipesPreviewFactory.links, onAdd: {}, onRemove: { _ in })
            .padding()
            .kodaPreview()
    }

    #Preview("Links · empty") {
        RecipeLinksSection(links: [], onAdd: {}, onRemove: { _ in })
            .padding()
            .kodaPreview()
    }

    #Preview("Links · dark") {
        RecipeLinksSection(links: RecipesPreviewFactory.links, onAdd: {}, onRemove: { _ in })
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Links · Mac", traits: .fixedLayout(width: 800, height: 400)) {
        RecipeLinksSection(links: RecipesPreviewFactory.links, onAdd: {}, onRemove: { _ in })
            .padding()
            .kodaPreview()
    }
#endif
