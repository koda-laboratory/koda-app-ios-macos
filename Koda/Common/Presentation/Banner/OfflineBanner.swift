import SwiftUI

// MARK: - Offline Banner

/// Discreet sync indicator: "Sin conexión · 3 cambios pendientes". Hidden while online.
struct OfflineBanner: View {
    let status: SyncStatus

    var body: some View {
        if !status.isOnline {
            HStack(spacing: KodaSpacing.xs) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(KodaColor.taupe)
                    .accessibilityHidden(true)
                Text(message)
                    .font(KodaTypography.footnote)
                    .foregroundStyle(KodaColor.textPrimary)
            }
            .padding(.horizontal, KodaSpacing.s + 2)
            .padding(.vertical, KodaSpacing.xs)
            .background(KodaColor.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(KodaColor.separator) }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("offline-banner")
            .transition(.opacity)
        }
    }

    private var message: LocalizedStringKey {
        status.pendingChanges == 0 ? "sync.offline" : "sync.offline.pending \(status.pendingChanges)"
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Offline banner") {
        OfflineBanner(status: SyncStatus(isOnline: false, pendingChanges: 2, isSyncing: false))
            .padding()
            .kodaPreview()
    }

    #Preview("Offline banner · dark") {
        OfflineBanner(status: SyncStatus(isOnline: false, pendingChanges: 0, isSyncing: false))
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Offline banner · Mac", traits: .fixedLayout(width: 600, height: 200)) {
        OfflineBanner(status: SyncStatus(isOnline: false, pendingChanges: 5, isSyncing: false))
            .kodaPreview()
    }
#endif
