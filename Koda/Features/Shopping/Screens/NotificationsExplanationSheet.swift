import SwiftUI

/// Koda's own explanation before the system notification prompt (asked the first time something is frozen).
struct NotificationsExplanationSheet: View {
    let onEnable: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: KodaSpacing.l) {
            Image(systemName: "snowflake")
                .font(.largeTitle)
                .foregroundStyle(KodaColor.taupe)
                .frame(width: 72, height: 72)
                .background(KodaColor.onyx, in: Circle())
                .accessibilityHidden(true)
            Text("notifications.explanation.title")
                .font(KodaTypography.title)
                .multilineTextAlignment(.center)
            Text("notifications.explanation.message")
                .font(KodaTypography.body)
                .foregroundStyle(KodaColor.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton("notifications.explanation.enable", systemImage: "bell", action: onEnable)
                .accessibilityIdentifier("notifications-enable")
            Button("notifications.explanation.later", action: onLater)
                .font(KodaTypography.subheadline)
                .foregroundStyle(KodaColor.brandText)
                .buttonStyle(.plain)
        }
        .padding(KodaSpacing.l)
        .frame(maxWidth: .infinity)
        .background(KodaColor.background)
        .presentationDetents([.large])
        .platformSheetSize(width: 440, height: 480)
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

    #Preview("Notifications explanation · Mac", traits: .fixedLayout(width: 440, height: 480)) {
        NotificationsExplanationSheet(onEnable: {}, onLater: {})
            .kodaPreview()
    }
#endif
