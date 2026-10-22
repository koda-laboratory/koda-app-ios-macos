import SwiftUI

/// The biometric lock: blurs the last content and offers "Desbloquear". Transparent while unlocked.
struct LockOverlay: View {
    @State private var viewModel: LockViewModel

    init(viewModel: LockViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.state != .unlocked {
                LockScreen(isAuthenticating: viewModel.state == .authenticating) {
                    Task { await viewModel.send(.unlock) }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
        .task { await viewModel.send(.appeared) }
    }
}

private struct LockScreen: View {
    let isAuthenticating: Bool
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: KodaSpacing.l) {
            Spacer()
            KodaArcs()
                .frame(width: 96)
            Text("lock.title")
                .font(KodaTypography.title)
                .foregroundStyle(KodaColor.textPrimary)
            Text("lock.message")
                .font(KodaTypography.callout)
                .foregroundStyle(KodaColor.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton("lock.unlock", systemImage: "faceid", isLoading: isAuthenticating, action: unlock)
                .frame(maxWidth: 280)
                .accessibilityIdentifier("lock-unlock")
            Spacer()
        }
        .padding(KodaSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .background(KodaColor.background.opacity(0.6))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Lock · iPhone") {
        LockOverlay(viewModel: AuthPreviewFactory.makeLockViewModel(locked: true))
            .kodaPreview()
    }

    #Preview("Lock · dark") {
        LockOverlay(viewModel: AuthPreviewFactory.makeLockViewModel(locked: true))
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Lock · Mac", traits: .fixedLayout(width: 1000, height: 700)) {
        LockOverlay(viewModel: AuthPreviewFactory.makeLockViewModel(locked: true))
            .kodaPreview()
    }
#endif
