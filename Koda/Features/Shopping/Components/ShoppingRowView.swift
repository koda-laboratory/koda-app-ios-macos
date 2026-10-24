import SwiftUI

/// The status dot: an outline to buy, filled walnut with a check when we have it, filled taupe with a snowflake
/// when it is in the freezer.
struct ShoppingStatusDot: View {
    let status: ShoppingItemStatus
    var size: CGFloat = KodaSize.statusDot

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
            Circle()
                .strokeBorder(stroke, lineWidth: 2)
            switch status {
            case .have:
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .heavy))
                    .foregroundStyle(KodaColor.cream)
                    .transition(.scale.combined(with: .opacity))
            case .frozen:
                Image(systemName: "snowflake")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(KodaColor.onyx)
                    .transition(.scale.combined(with: .opacity))
            case .pending:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .kodaAnimation(.spring(duration: 0.3), value: status)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch status {
        case .pending: .clear
        case .have: KodaColor.brand
        case .frozen: KodaColor.taupe
        }
    }

    private var stroke: Color {
        status == .have ? KodaColor.brand : KodaColor.taupe
    }
}

/// A product row: tap toggles "ya lo tenemos", the snowflake toggles "congelado".
struct ShoppingRowView: View {
    let row: ShoppingRow
    let meta: String
    var compact = false
    let onToggleHave: () -> Void
    let onToggleFrozen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggleHave) {
                HStack(spacing: KodaSpacing.s + 2) {
                    ShoppingStatusDot(status: row.status, size: compact ? 22 : KodaSize.statusDot)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.title)
                            .font(compact ? KodaTypography.subheadline : KodaTypography.body.weight(.semibold))
                            .foregroundStyle(titleColor)
                            .strikethrough(row.status == .have)
                        if !meta.isEmpty {
                            Text(verbatim: meta)
                                .font(KodaTypography.footnote)
                                .foregroundStyle(row.status == .frozen ? KodaColor.brandText : KodaColor.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, compact ? KodaSpacing.s - 2 : KodaSpacing.s + 2)
                .padding(.leading, compact ? 0 : KodaSpacing.m)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .platformHaptic(.selection, trigger: row.status)
            .accessibilityLabel(Text(verbatim: row.title))
            .accessibilityValue(Text(statusKey))
            .accessibilityHint(Text("shopping.row.hint"))
            .accessibilityIdentifier("shopping-row-\(row.id)")

            if !row.isText {
                Button(action: onToggleFrozen) {
                    Image(systemName: "snowflake")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(row.status == .frozen ? KodaColor.taupe : KodaColor.textTertiary.opacity(0.7))
                        // The filled circle stays smaller than the row so it keeps air above and below; the
                        // tap area is still the full hit target.
                        .frame(width: KodaSize.hitTarget - 12, height: KodaSize.hitTarget - 12)
                        .background(row.status == .frozen ? KodaColor.onyx : .clear, in: Circle())
                        .frame(width: KodaSize.hitTarget, height: KodaSize.hitTarget)
                        .contentShape(Circle())
                        .symbolEffect(.bounce, value: row.status == .frozen)
                }
                .buttonStyle(.plain)
                .padding(.trailing, KodaSpacing.xs)
                .accessibilityLabel(Text(row.status == .frozen ? "shopping.frozen.off" : "shopping.frozen.on"))
                .accessibilityIdentifier("shopping-frozen-\(row.id)")
            }
        }
    }

    private var titleColor: Color {
        switch row.status {
        case .pending: KodaColor.textPrimary
        case .have: KodaColor.textTertiary
        case .frozen: KodaColor.brandText
        }
    }

    private var statusKey: LocalizedStringKey {
        switch row.status {
        case .pending: "shopping.status.pending"
        case .have: "shopping.status.have"
        case .frozen: "shopping.status.frozen"
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Shopping rows") {
        VStack(spacing: 0) {
            ForEach(ShoppingPreviewFactory.rows) { row in
                ShoppingRowView(row: row, meta: "2 l · Mercadona", onToggleHave: {}, onToggleFrozen: {})
                Divider()
            }
        }
        .background(KodaColor.surface)
        .padding()
        .kodaPreview()
    }

    #Preview("Shopping rows · dark") {
        VStack(spacing: 0) {
            ForEach(ShoppingPreviewFactory.rows) { row in
                ShoppingRowView(row: row, meta: "", compact: true, onToggleHave: {}, onToggleFrozen: {})
            }
        }
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Shopping rows · Mac", traits: .fixedLayout(width: 700, height: 300)) {
        ShoppingRowView(row: ShoppingPreviewFactory.rows[0], meta: "1 kg", onToggleHave: {}, onToggleFrozen: {})
            .frame(width: 480)
            .kodaPreview()
    }
#endif
