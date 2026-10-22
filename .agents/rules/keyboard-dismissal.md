---
description: Dismiss the software keyboard when tapping outside a text input
alwaysApply: true
---

# Keyboard dismissal

Every SwiftUI screen or sheet containing a `TextField`, `SecureField`, `TextEditor`, or another editable text input must apply `.dismissKeyboard()` once to its outermost interactive container.

```swift
var body: some View {
    ScrollView {
        // Screen content and text inputs.
    }
    .dismissKeyboard()
}
```

The canonical modifier lives at `Koda/Common/Presentation/Keyboard/DismissKeyboard.swift` (add it with the first text-input screen if it does not exist yet). It calls `PlatformKeyboard.dismiss()` from `Koda/Core/Platform/`, which resigns the UIKit first responder on iPhone and is a no-op on macOS (hardware keyboard). Reuse it instead of adding screen-specific UIKit, gesture, or focus-management implementations; features must not import UIKit for this (see [`multiplatform`](multiplatform.md)).

Apply the modifier at screen level, not separately to each input. Keep field-specific `@FocusState` only when the screen also needs explicit focus traversal, validation focus, or submit behavior.

When adding or reviewing a text-input screen:

1. Confirm that `.dismissKeyboard()` is attached to the outermost interactive container.
2. Confirm that tapping outside every input still permits buttons, links, scrolling, and input selection to work normally.
3. Confirm the submit label and `.onSubmit` move focus or submit (`Next` between fields, `Done`/`Search`/`Send` on the last one); on the Mac, Return and Tab must behave the same way.
4. Validate the behavior on an iPhone and on the Mac.

## Keyboard margin

Every scrolling screen or sheet with a text input also applies `.keyboardMargin()` (`Koda/Common/Presentation/Keyboard/KeyboardMargin.swift`) next to `.dismissKeyboard()`. The system only scrolls a focused field until it touches the keyboard; the modifier adds bottom safe-area padding to the scroll view so the field keeps a gap above it. Do not reimplement this with `ScrollViewReader.scrollTo` on focus changes: the system's own keyboard scroll runs afterwards and overrides it.

Secure inputs use the shared `PasswordField` (`Common/Presentation/Input/`), which includes the show/hide eye button.
