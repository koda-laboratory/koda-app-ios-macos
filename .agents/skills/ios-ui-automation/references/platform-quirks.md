# Platform quirks

- **Identifiers**: `.accessibilityIdentifier` on a container may be overridden by children; attach it to the control itself. `.accessibilityElement(children: .combine)` merges text, so assert on the combined label or the identifier.
- **Lazy stacks**: off-screen rows are not in the hierarchy; use `scrollUntilVisible`.
- **Sheets**: sheets animate in; wait for animation end before asserting. On the Mac they are attached windows dismissed with toolbar buttons or Escape.
- **Keyboard**: the app dismisses the keyboard on outside taps (`.dismissKeyboard()`); in Maestro use `hideKeyboard` when needed.
- **Tab bar vs sidebar**: the `.sidebarAdaptable` `TabView` is a tab bar on iPhone and a sidebar on the Mac; select sections by identifier, not by position.
- **System alerts** (Face ID, notifications in the future): accept or deny them explicitly; they are not part of the app hierarchy. Face ID in the simulator: Features → Face ID → Matching Face.
- **Biometric lock**: the lock screen appears on cold start when enabled; disable it in the test household's profile or handle it in the clean-launch subflow.
- **Sync**: content written from another device arrives asynchronously; wait for the identifier instead of sleeping.
