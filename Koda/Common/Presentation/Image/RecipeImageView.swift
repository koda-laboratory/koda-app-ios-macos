import SwiftUI

/// A recipe image from Storage that fills its frame (cropped), with `placeholder` until it is available. A missing
/// image (not uploaded yet by the partner's device, or offline) is retried a few times while the view is visible.
struct RecipeImageView<Placeholder: View>: View {
    let path: String?
    var maxPixelSize = 800
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.recipeImageLoader) private var loader
    @State private var loaded: LoadedImage?

    var body: some View {
        Color.clear
            .overlay {
                if let loaded, loaded.path == path {
                    Image(decorative: loaded.image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    placeholder()
                }
            }
            .clipped()
            .animation(.easeOut(duration: 0.2), value: loaded?.path)
            .task(id: path) { await load() }
    }

    private func load() async {
        guard let path else {
            loaded = nil
            return
        }
        for attempt in 0..<4 {
            if let image = await loader.image(path, maxPixelSize) {
                loaded = LoadedImage(path: path, image: image)
                return
            }
            do {
                try await Task.sleep(for: .seconds(15 * (attempt + 1)))
            } catch {
                return
            }
        }
    }
}

private struct LoadedImage {
    let path: String
    let image: CGImage
}

// MARK: - Previews

#if DEBUG
    #Preview("Recipe image · placeholder") {
        RecipeImageView(path: nil) { KodaGradient.signature }
            .frame(width: 200, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card))
            .kodaPreview()
    }

    #Preview("Recipe image · Mac", traits: .fixedLayout(width: 600, height: 300)) {
        RecipeImageView(path: nil) { KodaGradient.signature }
            .frame(width: 400, height: 220)
            .kodaPreview()
    }
#endif
