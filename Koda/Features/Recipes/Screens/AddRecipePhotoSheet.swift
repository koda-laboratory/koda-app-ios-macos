import PhotosUI
import SwiftUI

/// "Añadir foto" (approved mockup `AddPhoto`): take a photo (iPhone) or choose one from Photos or, on the Mac, from a
/// file; "Usar como portada" starts on when the recipe has no cover yet. The photo is stored on the device and
/// uploads by itself when there is a connection.
struct AddRecipePhotoSheet: View {
    let recipeName: String
    let onPick: (Data, Bool) -> Void
    let onCancel: () -> Void

    private let hasNoCover: Bool
    @State private var asCover: Bool
    @State private var pickerItem: PhotosPickerItem?
    @State private var cameraRequest: CameraRequest?
    @State private var isImportingFile = false
    @State private var contentHeight: CGFloat = 420

    init(recipeName: String, asCover: Bool, onPick: @escaping (Data, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.recipeName = recipeName
        self.onPick = onPick
        self.onCancel = onCancel
        _asCover = State(initialValue: asCover)
        hasNoCover = asCover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: KodaSpacing.xxs) {
                    Text("recipe.photos.sheet.title")
                        .font(KodaTypography.title)
                        .foregroundStyle(KodaColor.textPrimary)
                    Text(verbatim: recipeName)
                        .font(KodaTypography.callout)
                        .foregroundStyle(KodaColor.textSecondary)
                }
                Spacer()
                if PlatformIdiom.current == .mac {
                    Button("common.cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
            }
            VStack(spacing: 0) {
                if PlatformCamera.isAvailable {
                    SourceRow(titleKey: "recipe.photos.sheet.camera", systemImage: "camera", isPrimary: true) {
                        cameraRequest = CameraRequest()
                    }
                    .accessibilityIdentifier("recipe-photo-camera")
                    Divider().overlay(KodaColor.background)
                }
                PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible) {
                    SourceRowLabel(
                        titleKey: "recipe.photos.sheet.library",
                        systemImage: "photo.on.rectangle",
                        isPrimary: !PlatformCamera.isAvailable
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recipe-photo-library")
                if PlatformIdiom.current == .mac {
                    Divider().overlay(KodaColor.background)
                    SourceRow(titleKey: "recipe.photos.sheet.file", systemImage: "folder", isPrimary: false) {
                        isImportingFile = true
                    }
                    .accessibilityIdentifier("recipe-photo-file")
                }
            }
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))

            Toggle(isOn: $asCover) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("recipe.photos.use-as-cover")
                        .font(KodaTypography.body.weight(.bold))
                        .foregroundStyle(KodaColor.textPrimary)
                    if hasNoCover {
                        Text("recipe.photos.sheet.cover-hint")
                            .font(KodaTypography.footnote)
                            .foregroundStyle(KodaColor.textSecondary)
                    }
                }
            }
            .tint(KodaColor.brand)
            .padding(.horizontal, KodaSpacing.m + 2)
            .padding(.vertical, KodaSpacing.s + 2)
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .accessibilityIdentifier("recipe-photo-as-cover")

            Text("recipe.photos.sheet.offline")
                .font(KodaTypography.caption)
                .foregroundStyle(KodaColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, KodaSpacing.l - 4)
        .padding(.top, KodaSpacing.l)
        .padding(.bottom, KodaSpacing.m)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            contentHeight = $0
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(KodaColor.background.ignoresSafeArea())
        .presentationDetents([.height(contentHeight)])
        .presentationBackground(KodaColor.background)
        .platformSheetSize(width: 460, height: 420)
        .task(id: pickerItem) { await loadPickedItem() }
        .platformFullScreenCover(item: $cameraRequest) { _ in
            CameraCaptureView { data in
                cameraRequest = nil
                if let data { onPick(data, asCover) }
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { onPick(data, asCover) }
        }
    }

    private func loadPickedItem() async {
        guard let pickerItem else { return }
        if let image = try? await pickerItem.loadTransferable(type: PickedImage.self) {
            onPick(image.data, asCover)
        }
        self.pickerItem = nil
    }
}

private struct CameraRequest: Identifiable {
    let id = UUID()
}

/// A row of the sources card.
private struct SourceRow: View {
    let titleKey: LocalizedStringResource
    let systemImage: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SourceRowLabel(titleKey: titleKey, systemImage: systemImage, isPrimary: isPrimary)
        }
        .buttonStyle(.plain)
    }
}

private struct SourceRowLabel: View {
    nonisolated let titleKey: LocalizedStringResource
    nonisolated let systemImage: String
    nonisolated let isPrimary: Bool

    /// Nonisolated: `PhotosPicker` builds its label in a nonisolated closure on macOS.
    nonisolated init(titleKey: LocalizedStringResource, systemImage: String, isPrimary: Bool) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.isPrimary = isPrimary
    }

    var body: some View {
        HStack(spacing: KodaSpacing.s + 2) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(isPrimary ? KodaColor.cream : KodaColor.brandText)
                .frame(width: 40, height: 40)
                .background(
                    isPrimary ? KodaColor.brand : KodaColor.chip,
                    in: RoundedRectangle(cornerRadius: KodaRadius.small, style: .continuous)
                )
            Text(titleKey)
                .font(KodaTypography.body.weight(.bold))
                .foregroundStyle(KodaColor.textPrimary)
            Spacer()
        }
        .padding(.horizontal, KodaSpacing.m + 2)
        .padding(.vertical, KodaSpacing.s + 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Add photo · no cover") {
        AddRecipePhotoSheet(recipeName: "Lentejas estofadas", asCover: true, onPick: { _, _ in }, onCancel: {})
            .kodaPreview()
    }

    #Preview("Add photo · with cover · dark") {
        AddRecipePhotoSheet(recipeName: "Tortilla de patata", asCover: false, onPick: { _, _ in }, onCancel: {})
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Add photo · Mac", traits: .fixedLayout(width: 460, height: 420)) {
        AddRecipePhotoSheet(recipeName: "Lentejas estofadas", asCover: true, onPick: { _, _ in }, onCancel: {})
            .kodaPreview()
    }
#endif
