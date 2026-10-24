import SwiftUI

// MARK: - Draft Banner

/// "Claude ha preparado el planning del 26 oct al 1 nov · Revisar".
struct DraftBanner: View {
    let rangeText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.s) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(KodaColor.brandText)
                    .accessibilityHidden(true)
                Text("draft.banner.message \(rangeText)")
                    .font(KodaTypography.callout)
                    .foregroundStyle(KodaColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("draft.banner.review")
                    .font(KodaTypography.subheadline.weight(.bold))
                    .foregroundStyle(KodaColor.brandText)
            }
            .padding(KodaSpacing.m)
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous)
                    .strokeBorder(KodaColor.brand, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .kodaHoverHighlight()
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draft-banner")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Draft banner") {
        DraftBanner(rangeText: "26 oct – 1 nov") {}
            .padding()
            .kodaPreview()
    }

    #Preview("Draft banner · dark") {
        DraftBanner(rangeText: "26 oct – 1 nov") {}
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Draft banner · Mac", traits: .fixedLayout(width: 700, height: 200)) {
        DraftBanner(rangeText: "26 oct – 1 nov") {}
            .frame(width: 480)
            .kodaPreview()
    }
#endif
