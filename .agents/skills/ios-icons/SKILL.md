---
name: ios-icons
description: Choose, size, and audit Koda icons on iPhone and Mac — SF Symbols in product UI, symbol rendering modes and effects, accessibility labels, and the app icon (iOS + macOS). Use when a screen needs a glyph, an icon looks wrong, or the app icon changes. Not for photos, recipe images, or emoji content.
---

# Icons

## Sources

- Product glyphs: **SF Symbols** through `Image(systemName:)`, `Label(_:systemImage:)`, and `Tab(_:systemImage:value:)`. Koda has no custom symbol catalog yet; if a glyph is missing from SF Symbols, add a custom `.symbolset` under `Koda/Resources/Assets.xcassets/Symbols/` exported from the SF Symbols app template, and reference it with `Image(_:)`.
- Content icons: recipes and products may carry an `emoji` field (PLAN section 3.2); render it as text, not as a symbol.
- App icon: `Koda/Resources/Assets.xcassets/AppIcon.appiconset/` (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`), covering iOS and macOS sizes. An Icon Composer `.icon` file may replace it for Liquid Glass layering.

## Rules

- Use symbols that exist on both iOS 26.5 and macOS 26.5; check availability in the SF Symbols app.
- When a symbol name repeats across a feature, keep it in one constant (for example a small `enum` in the feature's `Utils/`) instead of scattering string literals.
- Icon-only buttons need a localized accessibility label (`Label` with `.labelStyle(.iconOnly)` or `.accessibilityLabel`); decorative icons are hidden from accessibility.
- Size icons with fonts/text styles (`.font(KodaTypography.headline)`, `.imageScale`) so they follow Dynamic Type; avoid fixed frames except for intentional asset sizes.
- Tint with `KodaColor` tokens; use `.symbolRenderingMode(.hierarchical)` or `.palette` deliberately, not by default.
- Motion: `symbolEffect` for checks and state changes (PLAN section 10), respecting Reduce Motion.
- Toolbar and tab items use plain symbols so the system applies its own sizing and Liquid Glass styling (see `apple-design`, `references/hig/icons.md`).

## App icon

Produce every size from one approved 1024×1024 source without transparency (iOS) and the macOS sizes (16–1024 pt @1x/@2x). Check the icon on the Home Screen (light, dark, tinted) and in the Dock. The signature motif is the concentric "U" arcs in onyx, walnut, and taupe (`koda-design-system`).

## Audit

```bash
rg -n "systemName:|systemImage:" Koda KodaWidgets
```

Confirm every icon-only control has an accessibility label and every symbol exists on both platforms.
