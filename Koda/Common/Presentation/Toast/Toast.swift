import SwiftUI

// MARK: - Toast

/// A short, transient message raised by a ViewModel (it carries a string-catalog key, never resolved text).
struct Toast: Sendable, Equatable, Identifiable {
    enum Style: Sendable, Equatable {
        case info
        case error
    }

    let id = UUID()
    let messageKey: String
    var style: Style = .info

    static func error(_ error: KodaError) -> Toast {
        Toast(messageKey: error.localizedPresentationKey, style: .error)
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastView(toast: toast)
                        .padding(.top, KodaSpacing.xs)
                        .padding(.horizontal, KodaSpacing.m)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(2.5))
                            self.toast = nil
                        }
                        .onTapGesture { self.toast = nil }
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: toast)
    }
}

private struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: KodaSpacing.xs) {
            Image(systemName: toast.style == .error ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.style == .error ? KodaColor.error : KodaColor.taupe)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(toast.messageKey))
                .font(KodaTypography.subheadline)
                .foregroundStyle(KodaColor.cream)
        }
        .padding(.horizontal, KodaSpacing.m)
        .padding(.vertical, KodaSpacing.s)
        .background(KodaColor.onyx, in: Capsule())
        .shadow(color: KodaColor.onyx.opacity(0.2), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("toast")
    }
}

extension View {
    /// Shows `toast` at the top for a few seconds, then clears it.
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Toast") {
        @Previewable @State var toast: Toast? = Toast(messageKey: "shopping.toast.added")
        Button("common.done") { toast = Toast(messageKey: "shopping.toast.added") }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toast($toast)
            .kodaPreview()
    }

    #Preview("Toast · dark") {
        @Previewable @State var toast: Toast? = Toast(messageKey: "error.type.no-internet", style: .error)
        Color.clear
            .toast($toast)
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Toast · Mac", traits: .fixedLayout(width: 700, height: 300)) {
        @Previewable @State var toast: Toast? = Toast(messageKey: "shopping.toast.added")
        Color.clear
            .toast($toast)
            .kodaPreview()
    }
#endif
