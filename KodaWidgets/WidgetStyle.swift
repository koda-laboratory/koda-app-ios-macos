import SwiftUI
import WidgetKit

/// Koda's palette for the widgets (the extension does not compile the app's theme).
enum WidgetPalette {
    static let onyx = Color(red: 0.051, green: 0.051, blue: 0.051)
    static let walnut = Color(red: 0.349, green: 0.157, blue: 0.086)
    static let taupe = Color(red: 0.8, green: 0.627, blue: 0.592)
    static let cream = Color(red: 0.965, green: 0.933, blue: 0.922)
}

extension View {
    /// Cream text on the signature onyx-to-walnut gradient.
    func kodaWidgetStyle() -> some View {
        foregroundStyle(WidgetPalette.cream)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [WidgetPalette.onyx, WidgetPalette.walnut],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}
