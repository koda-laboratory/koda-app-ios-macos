import SwiftUI

extension View {
    /// Hides the iPhone navigation bar on screens with their own large header. The Mac keeps its window toolbar.
    func platformHidesNavigationBar() -> some View {
        #if os(iOS)
            toolbar(.hidden, for: .navigationBar)
        #else
            self
        #endif
    }

    /// Window title on the Mac for screens whose iPhone version shows the title in its own hero instead.
    func platformMacNavigationTitle(_ title: String) -> some View {
        #if os(macOS)
            navigationTitle(Text(verbatim: title))
        #else
            self
        #endif
    }

    /// Transparent navigation bar over a full-bleed hero on iPhone.
    func platformTransparentNavigationBar() -> some View {
        #if os(iOS)
            toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        #else
            self
        #endif
    }

    /// Inline navigation titles on iPhone pushed screens; the Mac has no display modes.
    func platformInlineNavigationTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }

    /// Mac sheets are attached windows without swipe-to-dismiss: give them a sensible size. No-op on iPhone.
    func platformSheetSize(width: CGFloat = 520, height: CGFloat = 640) -> some View {
        #if os(macOS)
            frame(minWidth: width - 60, idealWidth: width, minHeight: height - 80, idealHeight: height)
        #else
            self
        #endif
    }

    /// Email keyboard and content type on iPhone.
    func platformEmailField() -> some View {
        #if os(iOS)
            keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.username)
        #else
            textContentType(.username)
        #endif
    }

    /// Decimal keyboard on iPhone.
    func platformDecimalField() -> some View {
        #if os(iOS)
            keyboardType(.decimalPad)
        #else
            self
        #endif
    }

    /// Number keyboard on iPhone.
    func platformNumberField() -> some View {
        #if os(iOS)
            keyboardType(.numberPad)
        #else
            self
        #endif
    }
}
