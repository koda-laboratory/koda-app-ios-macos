import SwiftUI

/// The light / dark choice from Profile. A per-device UI preference kept in `@AppStorage`, applied at every
/// scene root with `.kodaAppearance()`.
enum AppAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct AppAppearanceModifier: ViewModifier {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance.colorScheme)
    }
}

extension View {
    /// Applies the appearance chosen in Profile.
    func kodaAppearance() -> some View {
        modifier(AppAppearanceModifier())
    }
}
