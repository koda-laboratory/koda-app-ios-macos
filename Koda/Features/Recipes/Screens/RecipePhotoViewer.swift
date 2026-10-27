import SwiftUI

/// Full-screen viewer (approved mockup `Viewer`): swipe between the images, "2 de 3", share, "Usar como portada"
/// and delete. A sheet window on the Mac. Shared by recipes and products (`bucket`).
struct RecipePhotoViewer: View {
    /// The recipe or product name, for the share preview.
    let title: String
    let gallery: [RecipeGalleryItem]
    let bucket: ImageBucket
    let onSetCover: (RecipeGalleryItem) -> Void
    let onDelete: (RecipeGalleryItem) -> Void
    let onClose: () -> Void

    @State private var currentPath: String?
    @State private var pendingDeletion: RecipeGalleryItem?
    @Environment(\.recipeImageLoader) private var loader

    init(
        title: String,
        gallery: [RecipeGalleryItem],
        bucket: ImageBucket = .recipes,
        initialPath: String,
        onSetCover: @escaping (RecipeGalleryItem) -> Void,
        onDelete: @escaping (RecipeGalleryItem) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.gallery = gallery
        self.bucket = bucket
        self.onSetCover = onSetCover
        self.onDelete = onDelete
        self.onClose = onClose
        _currentPath = State(initialValue: initialPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(gallery) { item in
                        ViewerPage(path: item.path, bucket: bucket)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(item.path)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentPath)
            .scrollIndicators(.hidden)
            PageDots(count: gallery.count, index: currentIndex ?? 0)
                .padding(.vertical, KodaSpacing.m)
            bottomBar
        }
        .background(KodaColor.onyx.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .onChange(of: gallery) { _, items in
            // The current image was deleted: stay on a neighbour.
            if let currentPath, !items.contains(where: { $0.path == currentPath }) {
                self.currentPath = items.first?.path
            }
        }
        .confirmationDialog(
            "recipe.photos.delete.confirm",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { item in
            Button("recipe.photos.delete", role: .destructive) { onDelete(item) }
        }
    }

    private var current: RecipeGalleryItem? {
        gallery.first { $0.path == currentPath } ?? gallery.first
    }

    private var currentIndex: Int? {
        gallery.firstIndex { $0.path == current?.path }
    }

    private var topBar: some View {
        HStack {
            CircleButton(systemImage: "xmark", labelKey: "common.close", action: onClose)
                .keyboardShortcut(.cancelAction)
            Spacer()
            if let currentIndex {
                Text("recipe.photos.viewer.position \(currentIndex + 1) \(gallery.count)")
                    .font(KodaTypography.subheadline.weight(.semibold))
                    .foregroundStyle(KodaColor.taupe)
            }
            Spacer()
            if let current, let url = loader.fileURL(current.path, bucket) {
                ShareLink(item: url, preview: SharePreview(Text(verbatim: title))) {
                    CircleIcon(systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("recipe.photos.share"))
            } else {
                CircleIcon(systemImage: "square.and.arrow.up").opacity(0.35).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, KodaSpacing.l - 4)
        .padding(.top, KodaSpacing.s)
    }

    private var bottomBar: some View {
        HStack(spacing: KodaSpacing.s - 2) {
            if let current {
                Button {
                    onSetCover(current)
                } label: {
                    Label(
                        current.isCover ? "recipe.photos.is-cover" : "recipe.photos.use-as-cover",
                        systemImage: current.isCover ? "checkmark" : "rectangle.inset.filled"
                    )
                    .font(KodaTypography.body.weight(.bold))
                    .foregroundStyle(KodaColor.walnut)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(KodaColor.cream, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(current.isCover)
                .opacity(current.isCover ? 0.6 : 1)
                .accessibilityIdentifier("recipe-photo-viewer-cover")
                Button {
                    pendingDeletion = current
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(KodaColor.error)
                        .frame(width: 52, height: 52)
                        .background(KodaColor.error.opacity(0.22), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("recipe.photos.delete"))
                .accessibilityIdentifier("recipe-photo-viewer-delete")
            }
        }
        .padding(.horizontal, KodaSpacing.l - 4)
        .padding(.bottom, KodaSpacing.l)
    }
}

/// One image, fitted to the page.
private struct ViewerPage: View {
    let path: String
    let bucket: ImageBucket
    @Environment(\.recipeImageLoader) private var loader
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(KodaColor.cream)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: path) { image = await loader.image(path, bucket, 2000) }
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: KodaSpacing.xs - 2) {
            ForEach(0..<count, id: \.self) { dot in
                Capsule()
                    .fill(dot == index ? KodaColor.cream : KodaColor.cream.opacity(0.35))
                    .frame(width: dot == index ? 18 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
        .accessibilityHidden(true)
    }
}

private struct CircleButton: View {
    let systemImage: String
    let labelKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) { CircleIcon(systemImage: systemImage) }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(labelKey))
    }
}

private struct CircleIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.bold))
            .foregroundStyle(KodaColor.cream)
            .frame(width: KodaSize.hitTarget, height: KodaSize.hitTarget)
            .background(KodaColor.cream.opacity(0.14), in: Circle())
            .contentShape(Circle())
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Photo viewer") {
        RecipePhotoViewer(
            title: "Tortilla de patata",
            gallery: RecipesPreviewFactory.gallery,
            initialPath: RecipesPreviewFactory.gallery[1].path,
            onSetCover: { _ in },
            onDelete: { _ in },
            onClose: {}
        )
        .kodaPreview()
    }

    #Preview("Photo viewer · cover") {
        RecipePhotoViewer(
            title: "Tortilla de patata",
            gallery: RecipesPreviewFactory.gallery,
            initialPath: RecipesPreviewFactory.gallery[0].path,
            onSetCover: { _ in },
            onDelete: { _ in },
            onClose: {}
        )
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Photo viewer · Mac", traits: .fixedLayout(width: 900, height: 700)) {
        RecipePhotoViewer(
            title: "Tortilla de patata",
            gallery: RecipesPreviewFactory.gallery,
            initialPath: RecipesPreviewFactory.gallery[0].path,
            onSetCover: { _ in },
            onDelete: { _ in },
            onClose: {}
        )
        .kodaPreview()
    }
#endif
