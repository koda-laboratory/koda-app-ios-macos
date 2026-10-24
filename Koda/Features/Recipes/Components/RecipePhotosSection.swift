import SwiftUI

/// "Fotos": the add tile and the gallery strip (the cover marked "Portada"), or the "Haz una foto cuando la cocines"
/// card when there are no images. Images can also be dropped onto the section (Mac, and iPhone drag and drop).
/// Context menu on each photo: "Usar como portada · Compartir · Eliminar".
struct RecipePhotosSection: View {
    let gallery: [RecipeGalleryItem]
    let isSaving: Bool
    let onAdd: () -> Void
    let onOpen: (RecipeGalleryItem) -> Void
    let onSetCover: (RecipeGalleryItem) -> Void
    let onDelete: (RecipeGalleryItem) -> Void
    let onDrop: (Data) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(titleKey: "recipe.photos")
                if !gallery.isEmpty {
                    Text(verbatim: "\(gallery.count)")
                        .font(KodaTypography.subheadline.weight(.semibold))
                        .foregroundStyle(KodaColor.textSecondary)
                }
            }
            if gallery.isEmpty {
                EmptyPhotosCard(isSaving: isSaving, action: onAdd)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: KodaSpacing.s - 2) {
                        AddPhotoTile(isSaving: isSaving, action: onAdd)
                        ForEach(gallery) { item in
                            PhotoThumbnail(
                                item: item,
                                onOpen: { onOpen(item) },
                                onSetCover: { onSetCover(item) },
                                onDelete: { onDelete(item) }
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous)
                    .strokeBorder(KodaColor.brandText, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(-KodaSpacing.xs)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: PickedImage.self) { images, _ in
            guard let first = images.first else { return false }
            onDrop(first.data)
            return true
        } isTargeted: {
            isDropTargeted = $0
        }
    }
}

/// Dashed tile at the start of the strip.
private struct AddPhotoTile: View {
    let isSaving: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: KodaSpacing.xxs) {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "camera").font(.title3)
                }
                Text(PlatformIdiom.current == .mac ? "recipe.photos.add-or-drop" : "recipe.photos.add")
                    .font(KodaTypography.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(KodaColor.brandText)
            .padding(KodaSpacing.xxs)
            .frame(width: KodaSize.photoThumbnail, height: KodaSize.photoThumbnail)
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous)
                    .strokeBorder(KodaColor.brandText.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.tile))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityLabel(Text("recipe.photos.add"))
        .accessibilityIdentifier("recipe-add-photo")
    }
}

/// "Haz una foto cuando la cocines": the gallery's empty state.
private struct EmptyPhotosCard: View {
    let isSaving: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.s + 2) {
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "camera").font(.title2)
                    }
                }
                .foregroundStyle(KodaColor.brandText)
                .frame(width: 48, height: 48)
                .background(KodaColor.chip, in: RoundedRectangle(cornerRadius: KodaRadius.small, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("recipe.photos.empty.title")
                        .font(KodaTypography.body.weight(.bold))
                        .foregroundStyle(KodaColor.textPrimary)
                    Text("recipe.photos.empty.message")
                        .font(KodaTypography.footnote)
                        .foregroundStyle(KodaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .padding(KodaSpacing.m)
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous)
                    .strokeBorder(KodaColor.brandText.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.medium))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityIdentifier("recipe-add-photo")
    }
}

/// A square photo with the "Portada" badge on the cover.
private struct PhotoThumbnail: View {
    let item: RecipeGalleryItem
    let onOpen: () -> Void
    let onSetCover: () -> Void
    let onDelete: () -> Void

    @Environment(\.recipeImageLoader) private var loader

    var body: some View {
        Button(action: onOpen) {
            RecipeImageView(path: item.path, maxPixelSize: 300) { KodaColor.chip }
                .frame(width: KodaSize.photoThumbnail, height: KodaSize.photoThumbnail)
                .clipShape(RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if item.isCover { CoverBadge().padding(KodaSpacing.xs - 2) }
                }
                .contentShape(RoundedRectangle(cornerRadius: KodaRadius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.isCover ? "recipe.photos.cover-photo" : "recipe.photos.photo"))
        .kodaHoverHighlight(cornerRadius: KodaRadius.tile)
        .contextMenu {
            if !item.isCover {
                Button("recipe.photos.use-as-cover", systemImage: "rectangle.inset.filled", action: onSetCover)
            }
            if let url = loader.fileURL(item.path) {
                ShareLink(item: url) { Label("recipe.photos.share", systemImage: "square.and.arrow.up") }
            }
            Button("recipe.photos.delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

/// "Portada" pill over a thumbnail.
struct CoverBadge: View {
    var body: some View {
        Text("recipe.photos.cover")
            .font(KodaTypography.caption2.weight(.bold))
            .foregroundStyle(KodaColor.cream)
            .padding(.horizontal, KodaSpacing.xs - 1)
            .padding(.vertical, 3)
            .background(KodaColor.onyx.opacity(0.7), in: Capsule())
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Photos · gallery") {
        RecipePhotosSection(
            gallery: RecipesPreviewFactory.gallery,
            isSaving: false,
            onAdd: {},
            onOpen: { _ in },
            onSetCover: { _ in },
            onDelete: { _ in },
            onDrop: { _ in }
        )
        .padding()
        .kodaPreview()
    }

    #Preview("Photos · empty") {
        RecipePhotosSection(
            gallery: [],
            isSaving: false,
            onAdd: {},
            onOpen: { _ in },
            onSetCover: { _ in },
            onDelete: { _ in },
            onDrop: { _ in }
        )
        .padding()
        .kodaPreview()
    }

    #Preview("Photos · saving · dark") {
        RecipePhotosSection(
            gallery: RecipesPreviewFactory.gallery,
            isSaving: true,
            onAdd: {},
            onOpen: { _ in },
            onSetCover: { _ in },
            onDelete: { _ in },
            onDrop: { _ in }
        )
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Photos · Mac", traits: .fixedLayout(width: 800, height: 260)) {
        RecipePhotosSection(
            gallery: RecipesPreviewFactory.gallery,
            isSaving: false,
            onAdd: {},
            onOpen: { _ in },
            onSetCover: { _ in },
            onDelete: { _ in },
            onDrop: { _ in }
        )
        .padding()
        .kodaPreview()
    }
#endif
