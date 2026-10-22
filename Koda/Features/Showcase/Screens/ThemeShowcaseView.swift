import SwiftUI

/// Temporary root screen (Phase 0/2): shows the design-system palette and the signature arcs so the app
/// launches with something on screen. Replaced by the tab root when the Phase 3 features land.
struct ThemeShowcaseView: View {
    private struct Swatch: Identifiable {
        let id: String
        let hex: String
        let color: Color
    }

    private let brandSwatches = [
        Swatch(id: "Onyx", hex: "#0D0D0D", color: KodaColor.onyx),
        Swatch(id: "Dark walnut", hex: "#592816", color: KodaColor.walnut),
        Swatch(id: "Rosy taupe", hex: "#CCA097", color: KodaColor.taupe),
    ]

    private let derivedSwatches = [
        Swatch(id: "Cream", hex: "#F6EEEB", color: KodaColor.cream),
        Swatch(id: "Walnut light", hex: "#7A3A22", color: KodaColor.walnutLight),
        Swatch(id: "Walnut deep", hex: "#2A140C", color: KodaColor.walnutDeep),
        Swatch(id: "Error", hex: "#B4533A", color: KodaColor.error),
        Swatch(id: "Success", hex: "#6E8B5E", color: KodaColor.success),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KodaSpacing.l) {
                hero
                SwatchGrid(titleKey: "showcase.brand", swatches: brandSwatches.map { ($0.id, $0.hex, $0.color) })
                SwatchGrid(titleKey: "showcase.derived", swatches: derivedSwatches.map { ($0.id, $0.hex, $0.color) })
            }
            .padding(KodaSpacing.m)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(KodaColor.background)
    }

    private var hero: some View {
        HStack(alignment: .bottom, spacing: KodaSpacing.l) {
            VStack(alignment: .leading, spacing: KodaSpacing.xs) {
                Text(verbatim: "Koda")
                    .font(KodaTypography.display)
                    .foregroundStyle(KodaColor.cream)
                Text("showcase.subtitle")
                    .font(KodaTypography.callout)
                    .foregroundStyle(KodaColor.taupe)
            }
            Spacer(minLength: 0)
            KodaArcs(colors: [KodaColor.taupe, KodaColor.cream, KodaColor.walnutLight], lineWidth: 14, gap: 8)
                .frame(width: 120)
        }
        .padding(KodaSpacing.l)
        .background(KodaGradient.signature, in: .rect(cornerRadius: KodaRadius.large))
    }
}

// MARK: - Components

private struct SwatchGrid: View {
    let titleKey: LocalizedStringKey
    let swatches: [(String, String, Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s) {
            Text(titleKey)
                .font(KodaTypography.headline)
                .foregroundStyle(KodaColor.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: KodaSpacing.s)], spacing: KodaSpacing.s) {
                ForEach(swatches, id: \.0) { name, hex, color in
                    VStack(alignment: .leading, spacing: KodaSpacing.xs) {
                        RoundedRectangle(cornerRadius: KodaRadius.small)
                            .fill(color)
                            .frame(height: 64)
                            .overlay {
                                RoundedRectangle(cornerRadius: KodaRadius.small).stroke(KodaColor.separator)
                            }
                        Text(verbatim: name)
                            .font(KodaTypography.callout.weight(.semibold))
                            .foregroundStyle(KodaColor.textPrimary)
                        Text(verbatim: hex)
                            .font(KodaTypography.caption.monospaced())
                            .foregroundStyle(KodaColor.textSecondary)
                    }
                    .padding(KodaSpacing.s)
                    .background(KodaColor.surface, in: .rect(cornerRadius: KodaRadius.medium))
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Showcase · iPhone") {
        ThemeShowcaseView()
            .kodaPreview()
    }

    #Preview("Showcase · Mac", traits: .fixedLayout(width: 1000, height: 700)) {
        ThemeShowcaseView()
            .kodaPreview()
    }
#endif
