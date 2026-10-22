import SwiftUI

// MARK: - Card

/// Solid content card (never Liquid Glass): surface fill, generous radius and padding.
struct KodaCard<Content: View>: View {
    var padding: CGFloat = KodaSpacing.m
    var highlight: Color?
    @ViewBuilder let content: () -> Content

    init(padding: CGFloat = KodaSpacing.m, highlight: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.highlight = highlight
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kodaCardBackground(highlight: highlight)
    }
}

extension View {
    /// The card surface, optionally outlined with `highlight` (the next meal, the defrost card).
    func kodaCardBackground(highlight: Color? = nil, fill: Color = KodaColor.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous)
                    .strokeBorder(highlight ?? KodaColor.separator, lineWidth: highlight == nil ? 0.5 : 2)
            }
    }

    /// Uppercase eyebrow label style.
    func kodaEyebrow(color: Color = KodaColor.textTertiary) -> some View {
        font(KodaTypography.eyebrow)
            .tracking(KodaTypography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Card") {
        VStack(spacing: KodaSpacing.m) {
            KodaCard {
                Text(verbatim: "Ensalada César").font(KodaTypography.cardTitle)
            }
            KodaCard(highlight: KodaColor.brand) {
                Text(verbatim: "Ensalada César").font(KodaTypography.cardTitle)
            }
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Card · dark") {
        KodaCard { Text(verbatim: "Ensalada César") }
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Card · Mac", traits: .fixedLayout(width: 700, height: 300)) {
        KodaCard { Text(verbatim: "Ensalada César") }
            .frame(width: 420)
            .kodaPreview()
    }
#endif
