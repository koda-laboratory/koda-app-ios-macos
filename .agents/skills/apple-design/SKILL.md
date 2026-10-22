---
name: apple-design
description: Review, audit, or improve Koda's native iPhone and Mac UI against Apple's Human Interface Guidelines, grounded in 72 HIG pages from developer.apple.com plus a design-craft lens. Use for design reviews, HIG compliance, accessibility audits, dark mode, Liquid Glass, navigation structure, toolbar and tab bar items, sheets, control and icon sizing, onboarding, forms, iPhone Duo or Mac window layouts, app icons, or requests like "is this good UI" and "make this look less generic", including screenshots, previews, and SwiftUI code. Not for implementing code alone (application-layer, swiftui-expert-skill) or for icon catalog changes (ios-icons).
---

# Apple design

Adapted from [dickwu/apple-design-skill](https://github.com/dickwu/apple-design-skill), trimmed to
what applies to a native SwiftUI app on iPhone (with Mac guidance kept where Koda needs it). Flutter, React Native, Tauri, Electron,
macOS-only, and unused-technology material was removed.

You are two people at once: a senior design reviewer who knows Apple's Human Interface Guidelines
cold, and the design lead of a small studio whose clients pay for a point of view. The first keeps
a design honest against the platform. The second keeps it from looking like every other app. Every
review carries both.

## Koda context

Apply the HIG through the repository's own contracts; they win where they are stricter.

- **Platforms.** Koda is one native SwiftUI app for iPhone and Mac (multiplatform target, not
  Catalyst, no iPad layout). Review both: `designing-for-ios.md` plus the `Desktop (macOS)`
  sections of each HIG page (sidebars, menus, windows, pointer and keyboard); iPad-only guidance does not apply.
- **Design system first.** Colors, typography, spacing (4/8/12/16/24/32), and radii (12/20/28,
  pill) come from `Koda/Common/Theme/` (`KodaColor`, `KodaTypography`, `KodaSpacing`,
  `KodaRadius`, `KodaGradient`, `KodaArcs`). Palette: onyx, dark walnut (brand), rosy taupe
  (accent). See the `koda-design-system` skill and the `swiftui-structure` rule.
- **Icons.** Koda uses SF Symbols (`Image(systemName:)`), so `sf-symbols.md` and `icons.md`
  apply directly. App icon changes go through `ios-icons`.
- **System chrome stays native.** The `.sidebarAdaptable` tab bar/sidebar, toolbars, and sheets are
  system components and adopt Liquid Glass on their own. Liquid Glass is never applied to content
  cards.
- **Implementation.** Turn findings into SwiftUI changes with `application-layer` and
  `swiftui-expert-skill`, then validate as the `development` rule requires (iPhone + Mac).

## The references

Everything lives under `references/` relative to this skill.

| Path | What it is |
| --- | --- |
| `references/hig-lookup.md` | Routing table: every kept page grouped by Apple's sections with Apple's one-line summary and the date Apple last changed it |
| `references/hig/<page>.md` | One file per HIG page in Apple's own wording. Platform headings are relabeled by device class: `Phone (iOS)`, `Tablet (iPadOS)`, `Mobile (iOS, iPadOS)`, `Desktop (macOS)`. Read the desktop sections for the Mac app; ignore tablet-only sections |
| `references/hig/liquid-glass.md` | Curated Liquid Glass guide with a review checklist and SwiftUI notes for Koda |

Rules for using them:

- **Read before you cite.** Open the file and quote the guideline. Do not review from memory.
- **Load about 8 to 12 files per review**, never the whole directory: the always-load set, then
  3 to 6 more for what is on screen.
- **Cite file and heading**, for example `toolbars.md › Best practices`. If no reference covers a
  point, say it is your judgment.

### Always load

`accessibility.md`, `layout.md`, `typography.md`, `color.md`, `designing-for-ios.md`, and
the `Desktop (macOS)` sections of `sidebars.md`, `split-views.md`, and `menus.md` for the Mac layout.

### Load by what is on screen

| The design shows | Load |
| --- | --- |
| Tabs, sidebar, split view, back navigation | `tab-bars.md`, `sidebars.md`, `split-views.md`, `toolbars.md` |
| Navigation bar or toolbar items | `toolbars.md`, `buttons.md`, `icons.md`, `sf-symbols.md` |
| Buttons, menus, actions | `buttons.md`, `menus.md`, `context-menus.md`, `pop-up-buttons.md`, `pull-down-buttons.md` |
| Sheets, dialogs, popovers, alerts | `modality.md`, `sheets.md`, `alerts.md`, `action-sheets.md`, `popovers.md` |
| Forms, text entry, pickers | `entering-data.md`, `text-fields.md`, `pickers.md`, `toggles.md`, `virtual-keyboards.md` |
| Lists, collections, cards, carousels | `lists-and-tables.md`, `collections.md`, `labels.md`, `scroll-views.md` |
| Search | `searching.md`, `search-fields.md` |
| Glass, blur, translucent bars | `liquid-glass.md`, `materials.md` |
| Dark appearance | `dark-mode.md` |
| Icons, symbols, app icon | `icons.md`, `sf-symbols.md`, `app-icons.md` |
| Images, covers, video | `images.md`, `image-views.md`, `playing-video.md` |
| Motion, transitions, haptics | `motion.md`, `playing-haptics.md` |
| Loading, progress, errors, empty states | `loading.md`, `feedback.md`, `progress-indicators.md`, `writing.md` |
| First run, sign-in, permissions | `onboarding.md`, `launching.md`, `managing-accounts.md`, `privacy.md`, `sign-in-with-apple.md` |
| Settings and profile | `settings.md`, `lists-and-tables.md`, `toggles.md` |
| Ratings and reviews | `rating-indicators.md`, `ratings-and-reviews.md` |
| Sharing | `activity-views.md` |
| Mac sidebar, split views, and window resizing | `sidebars.md`, `split-views.md`, `multitasking.md` (desktop sections), plus the `app-resizability` skill |
| iPhone Duo: two displays, a fold, bars on the side | `designing-for-iphone-duo.md`, `split-views.md`, `toolbars.md`, `tab-bars.md` |
| Notifications | `notifications.md`, `managing-notifications.md` |
| Brand expression | `branding.md`, `design-principles.md` |

Anything else: find it in `hig-lookup.md`.

## Apple's design principles

Apple's eight principles (`design-principles.md`) are the first filter: a screen that breaks a
principle has a bigger problem than any single guideline it breaks.

| Principle | Apple's line | The question you ask |
| --- | --- | --- |
| Purpose | Make something meaningful | What is this screen for, and does the design serve it? |
| Agency | Let people do things their own way | Can people explore, skip, and recover from mistakes? |
| Responsibility | Act in people's best interest | Are permissions, data use, and intent transparent? |
| Familiarity | Build on what people know | Do patterns match the platform and stay consistent? |
| Flexibility | Adapt to diverse contexts and needs | Does it work across sizes, text sizes, and abilities? |
| Simplicity | Be clear and direct | Has every element earned its place? |
| Craft | Care about every detail | Spacing, alignment, wording, animation: is it finished? |
| Delight | Make it human | Is there a feeling here, and is it the right one? Don't mistake delight for decoration |

## Review process

### Step 1: Establish context

Pin down the screen (iPhone, Mac, or both), the artifact (screenshot, preview render, simulator
capture, or SwiftUI code), the screen's single job, and what the user wants (full audit, a
specific worry, or a direction). Say what the artifact can and cannot verify: contrast needs real
color values from the theme, sizes need point values from code. A limit is not a finding.

### Step 2: Load references

Follow the loading tables and read the files.

### Step 3: Audit through five lenses, in this order

#### Lens 1: Accessibility (failures are Critical)

Distilled from `accessibility.md`, `typography.md`, and `color.md`:

- Text scales with Dynamic Type and layouts survive the largest sizes with hierarchy intact.
- Type sizes: default 17 pt, minimum 11 pt. Avoid light and thin weights for small text.
- Contrast: text up to 17 pt needs 4.5:1; text at 18 pt or larger, or bold text, needs 3:1.
  Compute it from theme values and show the numbers.
- Controls: default 44 by 44 pt hit region, minimum 28 by 28 pt. Spacing between controls matters
  as much as size.
- Nothing is conveyed by color alone. Every icon-only control has an accessibility label.
- Motion is optional and never the only carrier of meaning. Reduce Motion, Reduce Transparency,
  and Increase Contrast all have an answer.

#### Lens 2: Platform conventions (failures are usually High)

Distilled from `designing-for-ios.md`, `tab-bars.md`, `toolbars.md`, `sheets.md`,
`search-fields.md`, `gestures.md`, `layout.md`, and `designing-for-iphone-duo.md`:

- Top-level navigation is a tab bar that becomes a sidebar on the Mac (`.sidebarAdaptable`). Tabs navigate, they don't
  act. Few tabs, never hidden or disabled without reason, single-word labels where possible.
- Actions on the current view live in toolbars. Toolbar items use symbols at the system size,
  stay monochrome over content, get the prominent style only for key actions such as Done, and a
  More menu holds the overflow.
- Search that matters gets a primary position: a search tab, or a field at the bottom.
- Sheets: one at a time, a grabber when resizable, swipe to dismiss, a way out besides Done, and
  a medium detent considered for progressive disclosure.
- Content respects safe areas and one-handed reach. Swipe to go back works. iPhone Duo side bars
  follow system order.
- Light and dark appearance with no app-specific appearance switch, semantic colors, and Liquid
  Glass only on the floating functional layer, never in content (`liquid-glass.md`).

#### Lens 3: Visual design and craft (findings are High or Medium)

Distilled from `color.md`, `typography.md`, `layout.md`, `icons.md`, `materials.md`, and
`motion.md`:

- One color means one thing. Colors work in light, dark, and increased contrast.
- Few typefaces, a clear scale, weight and size carry hierarchy.
- Alignment, grouping, and indentation that show hierarchy. Layout follows available space, not
  device or orientation, with the same functions at any size.
- Icons share one visual language and match the weight and size of adjacent text. Custom icons
  are vector and labeled.
- Motion is purposeful, brief, cancellable, and rare on frequent interactions.

Then the craft lens:

- **Does it have a point of view?** Name the one thing this design would be remembered by, or say
  that it is a deliberately quiet utility.
- **Is it a template?** A palette, type pairing, or layout with no reason rooted in the product is
  a default, not a choice.
- **Is the boldness spent in one place?** One signature element, everything around it quiet.
  Branding defers to content, and brand color is saved for primary actions and status
  (`branding.md`).
- **Remove one accessory.** Ask what can go without loss. If nothing can, say so.

Familiar components carry navigation and controls, and a restyled one keeps familiar sizing,
placement, and behavior (`branding.md`); identity lives in color, type, imagery, tone, and a few
defining moments.

#### Lens 4: Interaction (findings are usually Medium)

Distilled from `feedback.md`, `loading.md`, `modality.md`, `alerts.md`, and `entering-data.md`:

- Something appears immediately while loading, people can keep working, and progress is
  determinate when possible.
- Feedback lives in the interface, not in alerts. Alerts are rare and never shown on launch.
- Destructive, irreversible actions get a warning and a Cancel.
- Modal views have an obvious way out and a single short task.
- Data entry offers choices over typing and validates dynamically.

#### Lens 5: Content and writing (findings are usually Medium)

Distilled from `writing.md`:

- Every label says what happens, and an action keeps its name through the whole flow.
- Capitalization is consistent with the rest of Koda's copy in both `en` and `es`.
- Errors say what went wrong and how to fix it. Empty screens invite the next action.
- No jargon, no filler, one job per element.

### Step 4: Write the report

```text
## Design review: <name>

### Summary
Two or three sentences. Overall rating: Excellent / Good / Needs work / Critical issues.

### Critical
- **What**: the problem, with numbers when you have them
- **Why**: the principle, cited as `file.md › Heading` with a short quote
- **Fix**: the concrete SwiftUI change, using Koda's theme and components

### Improvements
Same format, each finding tagged High, Medium, or Low.

### Craft notes
### What works
### Platform notes
iPhone versus Mac, and iPhone Duo where relevant.
```

Include only the sections that have content; Summary always appears. A strong design gets a short
review. Severity: **Critical** for accessibility failures or confusing convention breaks; **High**
for real friction, poor readability, or looking foreign on the platform; **Medium** for
suboptimal patterns or missed system components; **Low** for polish.

## Specialized modes

- **Component check.** Any single component, such as a toolbar item or a sheet: load its page and
  review against its best practices and the `Mobile`, `Phone`, and `Tablet` sections.
- **App icon.** `app-icons.md`, `icons.md`.
- **Accessibility audit.** `accessibility.md`, `voiceover.md`, `typography.md`, `color.md`,
  `motion.md`.
- **Dark mode.** `dark-mode.md`, `color.md`, `materials.md`.
- **Liquid Glass.** `liquid-glass.md`, `materials.md`, `color.md`, then the component pages in play.
- **Navigation structure.** `tab-bars.md`, `sidebars.md`, `split-views.md`, `toolbars.md`,
  `searching.md`, `layout.md`.
- **Onboarding and permissions.** `onboarding.md`, `launching.md`, `managing-accounts.md`,
  `privacy.md`.
- **Forms.** `entering-data.md`, `text-fields.md`, `pickers.md`, `toggles.md`,
  `virtual-keyboards.md`.

## Working rules

- **Numbers, not adjectives.** "Icon drawn at 28 pt inside a 44 pt toolbar item; system symbols
  render at about 17 pt" beats "too big".
- **Cite it or label it as judgment.** Never invent a guideline.
- **Speak SwiftUI and Koda's design system** in every fix.
- **Name the trade-off** when a guideline collides with a product need, then recommend.
- **Don't over-critique**, and don't flatten Koda's personality into a template.
