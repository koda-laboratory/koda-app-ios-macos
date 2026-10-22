---
name: ios-localization
description: Manage Koda localization on iPhone and Mac — Koda/Resources/Localizable.xcstrings (UI), Koda/Resources/InfoPlist.xcstrings (permission and Info.plist strings), and the planned AppShortcuts.xcstrings (Siri phrases). Use when adding or changing user-visible text, placeholders, plurals, accessibility labels, permissions, or App Shortcut phrases. Not for icons (ios-icons) or typography (koda-design-system).
---

# Localization

## Sources of truth

1. UI strings: `Koda/Resources/Localizable.xcstrings` (source language `en`, plus `es`).
2. Info.plist values and permission descriptions: `Koda/Resources/InfoPlist.xcstrings` (for example `NSFaceIDUsageDescription`).
3. Planned: `Koda/Resources/AppShortcuts.xcstrings` for App Shortcut phrases (Spanish phrases, each including `${applicationName}`; see `app-intents-specialist`), and `INAlternativeAppNames` ("Comidita").

Koda is used in Spanish by the household; English is the development/base language and every key must have both `en` and `es`. There is no store metadata (TestFlight only).

## References

- Read [xcstrings-schema.md](references/xcstrings-schema.md) for plurals, placeholders, and translation state.

## Using strings

The app target localizes from the main bundle; there is no `bundle: .module`. Widgets have their own strings in `KodaWidgets/`.

```swift
Text("shopping.add.placeholder")                     // LocalizedStringKey
Text(LocalizedStringKey(isExpanded ? "recipe.show-less" : "recipe.show-more"))
String(localized: "<key>")                            // outside SwiftUI views
```

- Keys are dotted, lowercase, feature-prefixed (`auth.`, `today.`, `planning.`, `shopping.`, `recipes.`, `products.`, `profile.`, `sync.`, `error.`, `tab.`, `command.`).
- Use `Text(verbatim:)` only for non-translatable content (URLs, emails, emoji, already-formatted values).
- ViewModels and error presentations carry keys, not resolved strings.
- Add translator-facing comments; mark agent-generated translations `needs_review` and never downgrade approved human translations.
- Keep placeholder count and types identical in every language.
- Dates and quantities use `FormatStyle` with the user's locale; meal-plan days are shown in the household time zone.

## Supported languages

English (`en`) and Spanish (`es`). The project `knownRegions` are `en`, `es`, and `Base`. Do not add a language without explicit product approval.

## Workflow

1. Add or edit the key in `Localizable.xcstrings` (Xcode's editor, or JSON preserving the format) for `en` and `es`.
2. Update `InfoPlist.xcstrings` when a permission or Info.plist value changes.
3. Validate:

   ```bash
   xcrun xcstringstool print Koda/Resources/Localizable.xcstrings > /dev/null
   xcrun xcstringstool print Koda/Resources/InfoPlist.xcstrings > /dev/null
   ```

4. Check the screen in both languages on iPhone and Mac (scheme App Language or launch arguments, see `ios-ui-automation`), including long Spanish strings in compact iPhone layouts and the Mac sidebar.
