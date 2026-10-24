---
name: koda-design-system
description: Apply Koda's look & feel on iPhone and Mac — the onyx / dark walnut / rosy taupe palette and derived colors, KodaColor/KodaSpacing/KodaRadius/KodaTypography/KodaGradient tokens, the signature KodaArcs concentric "U" motif, planned shared components, Liquid Glass usage, motion, Mac adaptations, accessibility, and previews. Use when building or reviewing any UI, adding a token or shared component, or choosing colors, type, spacing, or radii.
---

# Koda design system

Inspired by Airbnb and Revolut on top of native Liquid Glass: content first (large cards with an image or an XXL emoji), plenty of air, strong typographic hierarchy, a single accent, and haptic micro-interactions. Tokens live in `Koda/Common/Theme/`; shared components in `Koda/Common/Presentation/<Type>/`.

## Palette

| Token role | Value | Use |
| --- | --- | --- |
| Onyx | `#0D0D0D` | dark-mode background, light-mode primary text |
| Dark walnut (brand) | `#592816` | primary button, selected tab, highlighted surfaces, headers |
| Rosy taupe (accent) | `#CCA097` | chips, selection, checks, highlights, text on walnut |
| Cream (derived) | `#F6EEEB` | light-mode background |
| Walnut light (derived) | `#7A3A22` | pressed / hover |
| Taupe soft (derived) | taupe at 16–24 % | chip fills, separators |
| Walnut deep (derived) | `#2A140C` | elevated surface in dark mode |
| Error | `#B4533A` (`#D0684D` dark) | desaturated error; lighter in dark mode for text contrast |
| Success | `#6E8B5E` | desaturated success |

No other hues. Signature gradient: onyx → walnut, vertical (`KodaGradient.signature`), for the Today hero and login.

## Tokens

- `KodaColor`: brand constants (`onyx`, `walnut`, `taupe`, `cream`, `walnutLight`, `walnutDeep`, …) and adaptive semantic colors backed by asset-catalog color sets with light/dark variants: `background`, `surface`, `surfaceElevated`, `textPrimary`, `textSecondary`, `brand`, `onBrand`, `accent`, `separator`, `error`, `success`. Features use the **semantic** colors; brand constants are for the motif and special surfaces.
- `KodaSpacing`: `xxs` 4, `xs` 8, `s` 12, `m` 16, `l` 24, `xl` 32.
- `KodaRadius`: `small` 12, `medium` 20, `large` 28, `pill` (capsule).
- `KodaTypography`: SF Pro Rounded for display titles; `display` is the 34 pt bold rounded large title; plus `title`, `headline`, `body`, `callout`, `caption`, all built on text styles so they scale with Dynamic Type.
- `KodaGradient.signature`.
- `.kodaPreview()`: preview wrapper installing the Koda background and environment.

Read the current files in `Koda/Common/Theme/` for exact names before using them; add a token there (with light/dark values) rather than hard-coding a value in a feature.

## Signature motif: `KodaArcs`

Concentric "U" arcs in onyx, walnut, and taupe. Each arc can be filled with a progress value (0…1). Uses:

- Today hero: one arc per meal of the day, filling when the meal is marked as eaten (animate the fill; respect Reduce Motion).
- Login background and empty states.

Keep it decorative (`accessibilityHidden(true)`) unless it conveys progress; then expose an accessibility value ("2 de 3 comidas").

## Components (planned)

`KodaCard`, `MealCard`, `RecipeTile`, `ChipView`, `SectionHeader`, `EmptyStateView`, `PrimaryButton` (`.glassProminent`), `QuickAddField`, `CheckRow`, `WeekStrip` (Revolut-style week selector), `StatPill`, `OfflineBanner` ("Sin conexión · N cambios pendientes"), `DraftBanner` ("Claude ha preparado un borrador de planning"). Create each in `Common/Presentation/<Type>/` the first time a feature needs it, with previews for iPhone and Mac, light and dark.

## Rules

- **Liquid Glass** only for navigation and controls: tab bar / sidebar, toolbars, the "+" button, sheets, `PrimaryButton`. Never on content cards.
- **Motion**: zoom transition from card to detail, `symbolEffect` on checks; animate state changes with `kodaAnimation(_:value:)` and the `KodaMotion` tokens (`Common/Theme/KodaMotion.swift`), which turn off with Reduce Motion. Use `KodaMotion.animation(_:reduceMotion:)` inside `withAnimation`.
- **Haptics**: `platformHaptic(_:trigger:)` (`Core/Platform/PlatformHaptics.swift`) on meaningful actions — check, add, delete, favourite. It plays on iPhone only; never call `sensoryFeedback` directly.
- **Mac**: slightly higher density, hover states (`kodaHoverHighlight(cornerRadius:)` on interactive cards), keyboard shortcuts, resizable windows (`app-resizability`), sidebar + detail columns.
- **Accessibility**: Dynamic Type (no fixed font sizes), VoiceOver labels, Reduce Motion, Reduce Transparency (opaque fallback for glass), sufficient contrast of taupe text (use it on walnut/onyx, not on cream for body text).
- **Dark mode** is first-class: verify every screen in both appearances.
- Before implementing a main screen, a high-fidelity mockup of Today, Planning, Shopping, and Recipes on iPhone and Mac is validated.

## Previews

Every token showcase and component has `#Preview`s ending in `.kodaPreview()`, with iPhone and Mac variants and light/dark (see the `swiftui-structure` rule).
