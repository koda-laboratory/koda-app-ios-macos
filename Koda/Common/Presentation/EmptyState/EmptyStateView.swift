import SwiftUI

// MARK: - Empty State

/// Empty list or screen: the signature arcs, a title, a message and an optional action.
struct EmptyStateView: View {
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey
    var actionKey: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: KodaSpacing.m) {
            KodaArcs()
                .frame(width: 72)
            Text(titleKey)
                .font(KodaTypography.sectionTitle)
                .foregroundStyle(KodaColor.textPrimary)
            Text(messageKey)
                .font(KodaTypography.callout)
                .foregroundStyle(KodaColor.textSecondary)
                .multilineTextAlignment(.center)
            if let actionKey, let action {
                Button(actionKey, action: action)
                    .buttonStyle(.kodaPill())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KodaSpacing.xl)
        .padding(.horizontal, KodaSpacing.l)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Empty state") {
        EmptyStateView(titleKey: "shopping.empty.title", messageKey: "shopping.empty.message")
            .kodaPreview()
    }

    #Preview("Empty state · dark") {
        EmptyStateView(
            titleKey: "recipes.empty.title",
            messageKey: "recipes.empty.message",
            actionKey: "recipes.new"
        ) {}
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Empty state · Mac", traits: .fixedLayout(width: 900, height: 500)) {
        EmptyStateView(titleKey: "shopping.empty.title", messageKey: "shopping.empty.message")
            .kodaPreview()
    }
#endif
