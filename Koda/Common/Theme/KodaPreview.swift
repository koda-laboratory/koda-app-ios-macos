import SwiftUI

extension View {
    /// Finishes every preview: fills the canvas with the Koda background and applies the brand tint, like the
    /// app root.
    func kodaPreview() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KodaColor.background)
            .tint(KodaColor.brand)
    }
}
