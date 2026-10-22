import SwiftUI

// MARK: - Primary Button

/// The main call to action of a screen or sheet (Liquid Glass prominent, tinted with the brand).
struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(KodaColor.cream)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(titleKey)
                    .font(KodaTypography.headline)
            }
            .frame(maxWidth: .infinity, minHeight: KodaSize.hitTarget)
        }
        .buttonStyle(.glassProminent)
        .tint(KodaColor.brand)
        .controlSize(.large)
        .disabled(isLoading)
    }
}

// MARK: - Pill Button Style

/// Solid capsule buttons used inside content cards ("Hecho", "Cambiar", "Añadir al planning"). Cards never use
/// Liquid Glass, so these are opaque.
struct KodaPillButtonStyle: ButtonStyle {
    enum Kind {
        case brand
        case inverse
        case accent
        case outline
    }

    var kind: Kind = .brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KodaTypography.subheadline.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, KodaSpacing.m)
            .frame(minHeight: KodaSize.hitTarget - KodaSpacing.xxs)
            .background(background(isPressed: configuration.isPressed), in: Capsule())
            .overlay {
                if kind == .outline {
                    Capsule().strokeBorder(KodaColor.brand.opacity(0.3))
                }
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .brand: KodaColor.cream
        case .inverse: KodaColor.onInverse
        case .accent: KodaColor.onyx
        case .outline: KodaColor.brandText
        }
    }

    private func background(isPressed: Bool) -> Color {
        switch kind {
        case .brand: isPressed ? KodaColor.walnutLight : KodaColor.brand
        case .inverse: KodaColor.inverse
        case .accent: KodaColor.taupe
        case .outline: .clear
        }
    }
}

extension ButtonStyle where Self == KodaPillButtonStyle {
    static func kodaPill(_ kind: KodaPillButtonStyle.Kind = .brand) -> KodaPillButtonStyle {
        KodaPillButtonStyle(kind: kind)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Buttons") {
        VStack(spacing: KodaSpacing.m) {
            PrimaryButton("common.save") {}
            PrimaryButton("common.save", isLoading: true) {}
            HStack {
                Button("common.done") {}.buttonStyle(.kodaPill())
                Button("common.done") {}.buttonStyle(.kodaPill(.inverse))
                Button("common.done") {}.buttonStyle(.kodaPill(.outline))
            }
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Buttons · dark") {
        VStack(spacing: KodaSpacing.m) {
            PrimaryButton("common.save", systemImage: "cart") {}
            Button("common.done") {}.buttonStyle(.kodaPill(.inverse))
        }
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Buttons · Mac", traits: .fixedLayout(width: 600, height: 300)) {
        PrimaryButton("common.save") {}
            .frame(width: 320)
            .kodaPreview()
    }
#endif
