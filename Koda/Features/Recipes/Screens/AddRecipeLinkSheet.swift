import SwiftUI

/// "Añadir vídeo" (approved mockup "Añadir vídeo · hoja"): a link field with "Pegar", a live preview of the detected
/// platform and account, and "Añadir" once the text holds a valid `http(s)` URL.
struct AddRecipeLinkSheet: View {
    @State private var viewModel: AddRecipeLinkViewModel
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AddRecipeLinkViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KodaSpacing.s) {
                    LinkField(
                        text: $viewModel.text,
                        isValid: viewModel.detection != nil,
                        isFocused: $isFieldFocused,
                        onPaste: { Task { await viewModel.send(.pasted(PlatformPasteboard.string())) } },
                        onSubmit: { Task { await viewModel.send(.submit) } }
                    )
                    if let detection = viewModel.detection {
                        DetectedLinkRow(presentation: RecipeLinkPresentation(info: detection))
                            .transition(.opacity)
                    }
                    Text("recipe.links.sheet.footnote")
                        .font(KodaTypography.footnote)
                        .foregroundStyle(KodaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, KodaSpacing.xs)
                }
                .padding(.horizontal, KodaSpacing.m)
                .padding(.top, KodaSpacing.s)
                .kodaAnimation(value: viewModel.detection)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(KodaColor.background)
            .navigationTitle(Text("recipe.links.sheet.title"))
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .accessibilityIdentifier("recipe-link-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("recipe.links.sheet.add") { Task { await viewModel.send(.submit) } }
                        .disabled(!viewModel.canSubmit)
                        .accessibilityIdentifier("recipe-link-add")
                }
            }
            .dismissKeyboard()
            .keyboardMargin()
            .toast($viewModel.toast)
        }
        .presentationDetents([.medium])
        .presentationBackground(KodaColor.background)
        .platformSheetSize(width: 480, height: 340)
        .platformHaptic(.success, trigger: viewModel.state) { _, state in state == .completed }
        .onChange(of: viewModel.state) {
            if viewModel.state == .completed { dismiss() }
        }
        .onAppear { isFieldFocused = true }
    }
}

/// The URL field with "Pegar" inside its capsule; the border turns walnut while editing.
private struct LinkField: View {
    @Binding var text: String
    let isValid: Bool
    var isFocused: FocusState<Bool>.Binding
    let onPaste: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: KodaSpacing.xs) {
            TextField("recipe.links.sheet.placeholder", text: $text)
                .textFieldStyle(.plain)
                .font(KodaTypography.body)
                .foregroundStyle(KodaColor.textPrimary)
                .platformURLField()
                .submitLabel(.done)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("recipe-link-url")
            Button(action: onPaste) {
                Text("recipe.links.sheet.paste")
                    .font(KodaTypography.subheadline.weight(.bold))
                    .foregroundStyle(KodaColor.brandText)
                    .padding(.horizontal, KodaSpacing.s)
                    .frame(minHeight: KodaSize.chipHeight)
                    .background(KodaColor.chip, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recipe-link-paste")
        }
        .padding(.leading, KodaSpacing.m)
        .padding(.trailing, KodaSpacing.xs - 2)
        .frame(minHeight: KodaSize.fieldHeight)
        .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous)
                .strokeBorder(isFocused.wrappedValue ? KodaColor.brand : KodaColor.separator, lineWidth: 1.5)
        )
    }
}

/// The detected platform and account, with a check.
private struct DetectedLinkRow: View {
    let presentation: RecipeLinkPresentation

    var body: some View {
        HStack(spacing: KodaSpacing.s) {
            RecipeLinkTile(presentation: presentation)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: presentation.title)
                    .font(KodaTypography.body.weight(.bold))
                    .foregroundStyle(KodaColor.textPrimary)
                Text(verbatim: presentation.info.account ?? presentation.info.source)
                    .font(KodaTypography.footnote)
                    .foregroundStyle(KodaColor.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(KodaTypography.body.weight(.semibold))
                .foregroundStyle(KodaColor.success)
                .accessibilityLabel(Text("recipe.links.sheet.valid"))
        }
        .padding(KodaSpacing.m)
        .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recipe-link-preview")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Add video · filled") {
        Color.clear.sheet(isPresented: .constant(true)) {
            AddRecipeLinkSheet(
                viewModel: RecipesPreviewFactory.makeAddRecipeLinkViewModel(
                    text: "https://www.tiktok.com/@cocinaconana/video/7301234567890"
                )
            )
        }
        .kodaPreview()
    }

    #Preview("Add video · empty · dark") {
        Color.clear.sheet(isPresented: .constant(true)) {
            AddRecipeLinkSheet(viewModel: RecipesPreviewFactory.makeAddRecipeLinkViewModel())
        }
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Add video · Mac", traits: .fixedLayout(width: 480, height: 340)) {
        AddRecipeLinkSheet(
            viewModel: RecipesPreviewFactory.makeAddRecipeLinkViewModel(
                text: "https://youtube.com/shorts/aBcD1234xyz"
            )
        )
        .kodaPreview()
    }
#endif
