import SwiftUI

// MARK: - Hover Highlight

/// Pointer hover on an interactive card (the Mac): a brand outline and a slight lift. The iPhone has no pointer, so
/// it never shows there.
private struct HoverHighlightModifier: ViewModifier {
    let cornerRadius: CGFloat
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(KodaColor.brandText.opacity(0.45), lineWidth: 1.5)
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .scaleEffect(isHovering && !reduceMotion ? 1.01 : 1)
            .animation(KodaMotion.animation(KodaMotion.hover, reduceMotion: reduceMotion), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    /// Outlines and lifts an interactive card while the pointer is over it.
    func kodaHoverHighlight(cornerRadius: CGFloat = KodaRadius.card) -> some View {
        modifier(HoverHighlightModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Hover highlight") {
        KodaCard {
            Text(verbatim: "Hover me")
                .font(KodaTypography.body)
        }
        .kodaHoverHighlight()
        .padding()
        .kodaPreview()
    }

    #Preview("Hover highlight · dark") {
        KodaCard {
            Text(verbatim: "Hover me")
                .font(KodaTypography.body)
        }
        .kodaHoverHighlight()
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }
#endif
