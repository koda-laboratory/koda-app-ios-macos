import SwiftUI

/// Koda's own explanation before the system notification prompt (asked the first time something is frozen).
struct NotificationsExplanationSheet: View {
    let onEnable: () -> Void
    let onLater: () -> Void
    @State private var contentHeight: CGFloat = 420

    var body: some View {
        VStack(spacing: KodaSpacing.l) {
            Image(systemName: "snowflake")
                .font(.largeTitle)
                .foregroundStyle(KodaColor.taupe)
                .frame(width: 72, height: 72)
                .background(KodaColor.onyx, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: KodaSpacing.s) {
                Text("notifications.explanation.title")
                    .font(KodaTypography.title)
                    .foregroundStyle(KodaColor.textPrimary)
                Text("notifications.explanation.message")
                    .font(KodaTypography.body)
                    .foregroundStyle(KodaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: KodaSpacing.s) {
                PrimaryButton("notifications.explanation.enable", systemImage: "bell", action: onEnable)
                    .accessibilityIdentifier("notifications-enable")
                Button("notifications.explanation.later", action: onLater)
                    .font(KodaTypography.subheadline.weight(.semibold))
                    .foregroundStyle(KodaColor.brandText)
                    .frame(minHeight: KodaSize.hitTarget)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, KodaSpacing.l)
        .padding(.top, KodaSpacing.xl)
        .padding(.bottom, KodaSpacing.m)
        .frame(maxWidth: .infinity)
        // The sheet is as tall as its content on iPhone; the background fills the whole sheet on both platforms.
        .onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            contentHeight = $0
        }
        .frame(maxHeight: .infinity)
        .background(KodaColor.background.ignoresSafeArea())
        .presentationDetents([.height(contentHeight)])
        .presentationBackground(KodaColor.background)
        .platformSheetSize(width: 440, height: 400)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Notifications explanation") {
        NotificationsExplanationSheet(onEnable: {}, onLater: {})
            .kodaPreview()
    }

    #Preview("Notifications explanation · dark") {
        NotificationsExplanationSheet(onEnable: {}, onLater: {})
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Notifications explanation · Mac", traits: .fixedLayout(width: 440, height: 400)) {
        NotificationsExplanationSheet(onEnable: {}, onLater: {})
            .kodaPreview()
    }
#endif
