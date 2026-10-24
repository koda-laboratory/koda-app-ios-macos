import SwiftUI

// MARK: - Hit Target

/// Grows the tappable area of a small label to `minimum` points (44 by default) without changing its layout:
/// the content shape is padded out and the padding is taken back.
private struct HitTargetModifier: ViewModifier {
    let minimum: CGFloat
    @State private var size = CGSize.zero

    func body(content: Content) -> some View {
        let horizontal = max(0, (minimum - size.width) / 2)
        let vertical = max(0, (minimum - size.height) / 2)
        content
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                size = $0
            }
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .contentShape(Rectangle())
            .padding(.horizontal, -horizontal)
            .padding(.vertical, -vertical)
    }
}

extension View {
    /// Apply to the label of a small text or glyph button so its hit area reaches `KodaSize.hitTarget`.
    func kodaHitTarget(minimum: CGFloat = KodaSize.hitTarget) -> some View {
        modifier(HitTargetModifier(minimum: minimum))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Hit target") {
        Button {
        } label: {
            Text(verbatim: "Vaciar")
                .font(KodaTypography.subheadline.weight(.bold))
                .foregroundStyle(KodaColor.brandText)
                .kodaHitTarget()
                .border(KodaColor.separator)
        }
        .buttonStyle(.plain)
        .kodaPreview()
    }

    #Preview("Hit target · dark") {
        Button {
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(KodaColor.textTertiary)
                .kodaHitTarget()
        }
        .buttonStyle(.plain)
        .kodaPreview()
        .preferredColorScheme(.dark)
    }
#endif
