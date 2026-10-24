import SwiftUI

#if os(iOS)
    import UIKit
#endif

extension View {
    /// Dismisses the software keyboard when the user taps anywhere in the window, without consuming the tap.
    ///
    /// A SwiftUI `onTapGesture` on a screen takes taps away from `Form` rows (buttons, toggles, menus), so on
    /// iPhone this installs a UIKit recognizer on the window with `cancelsTouchesInView = false` while the screen
    /// is on screen. A no-op on the Mac (hardware keyboard).
    func platformKeyboardDismissTap() -> some View {
        #if os(iOS)
            background(KeyboardDismissTapInstaller().frame(width: 0, height: 0))
        #else
            self
        #endif
    }
}

#if os(iOS)
    private struct KeyboardDismissTapInstaller: UIViewRepresentable {
        func makeUIView(context: Context) -> InstallerView { InstallerView() }

        func updateUIView(_ uiView: InstallerView, context: Context) {}

        static func dismantleUIView(_ uiView: InstallerView, coordinator: ()) {
            uiView.uninstall()
        }
    }

    private final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private var recognizer: UITapGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            uninstall()
            guard let window else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            recognizer = tap
        }

        func uninstall() {
            guard let recognizer else { return }
            recognizer.view?.removeGestureRecognizer(recognizer)
            self.recognizer = nil
        }

        @objc private func dismissKeyboard() {
            PlatformKeyboard.dismiss()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Taps on a text input keep the keyboard up (moving the cursor, focusing another field), and taps
            // on a UIKit control (a switch, a stepper) stay entirely with that control.
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current is UIControl { return false }
                view = current.superview
            }
            return true
        }
    }
#endif
