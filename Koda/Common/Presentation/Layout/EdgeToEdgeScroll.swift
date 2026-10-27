import SwiftUI

// MARK: - Edge-to-edge horizontal scroll

extension View {
    /// Lets a horizontal scroll view run under its container's side padding so its content slides out to the edge
    /// of the screen instead of being cut at the padding. `inset` gives that space back as content margins, so the
    /// first and last items still line up with the rest of the screen when the scroll is at either end.
    ///
    /// `inset` must match the horizontal padding of the container the scroll view sits in.
    func kodaEdgeToEdgeScroll(inset: CGFloat = KodaSpacing.l - 4) -> some View {
        contentMargins(.horizontal, inset, for: .scrollContent)
            .padding(.horizontal, -inset)
    }
}

// MARK: - Previews

#if DEBUG
    private struct EdgeToEdgeScrollPreview: View {
        var body: some View {
            VStack(alignment: .leading, spacing: KodaSpacing.s) {
                Text(verbatim: "Hace tiempo que no").font(KodaTypography.sectionTitle)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KodaSpacing.s) {
                        ForEach(0..<5) { index in
                            RoundedRectangle(cornerRadius: KodaRadius.large - 4, style: .continuous)
                                .fill(index.isMultiple(of: 2) ? KodaColor.walnut : KodaColor.taupe)
                                .frame(width: 230, height: 150)
                        }
                    }
                }
                .kodaEdgeToEdgeScroll()
            }
            .padding(.horizontal, KodaSpacing.l - 4)
            .kodaPreview()
        }
    }

    #Preview("Edge-to-edge scroll · iPhone") {
        EdgeToEdgeScrollPreview()
    }

    #Preview("Edge-to-edge scroll · dark") {
        EdgeToEdgeScrollPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Edge-to-edge scroll · Mac", traits: .fixedLayout(width: 800, height: 300)) {
        EdgeToEdgeScrollPreview()
    }
#endif
