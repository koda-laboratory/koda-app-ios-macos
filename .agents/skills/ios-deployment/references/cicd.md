# CI/CD

Two GitHub Actions workflows live in `.github/workflows/`. Read them before changing lanes; local fastlane and CI must behave identically.

## `ci.yml` — every push and pull request

- Runner `macos-26` with Xcode 27.
- A matrix job per platform builds scheme `Koda` (`generic/platform=iOS Simulator` / `platform=macOS`) and runs `KodaTests` (iPhone 17 simulator / this Mac), all with `CODE_SIGNING_ALLOWED=NO`. The target's SwiftLint build phase runs too (SwiftLint is installed with Homebrew).
- Needs no secrets: when `Configuration/Koda.private.xcconfig` is absent (`#include?`), `SUPABASE_PUBLISHABLE_KEY` resolves to an empty value and the app still builds.
- A separate job runs `swift-format lint --strict` on `Koda`, `KodaWidgets`, and `KodaTests`.

## `testflight-monthly.yml` — keep a TestFlight build alive

- Triggers: `schedule` with cron `17 4 1 * *` (04:17 UTC on the 1st of every month) and `workflow_dispatch`.
- Runner `macos-26`, `ruby/setup-ruby` with bundler cache, SPM cache.
- Steps: checkout with write permission → `bundle install` → optional `Configuration/Koda.private.xcconfig` from the `SUPABASE_PUBLISHABLE_KEY` secret → `scripts/bump_build_version.sh` (one shared bump) → `bundle exec fastlane ios pipeline_build_upload bump_version:false commit_version:false` and the same for `mac` (each lane creates the temporary keychain `koda-ci.keychain` once, protected by `MATCH_KEYCHAIN_PASSWORD`, and runs match read-only into it; archive, upload, distribute to "House" after processing) → delete the keychain → commit `chore: bump build to N [skip ci]` → push to `main`.
- Repository secrets: `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION` (base64 `user:token` with read access to `koda-laboratory/mobile-macos-ios-certs`), `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT` (base64 of the `.p8`, decoded with `is_key_content_base64: true`), `MATCH_KEYCHAIN_PASSWORD` (temporary CI keychain), and the optional `SUPABASE_PUBLISHABLE_KEY` written into `Configuration/Koda.private.xcconfig` before archiving.

## Versioning

`CURRENT_PROJECT_VERSION` must increase for every TestFlight upload and is shared by the iOS and macOS builds of the same run. `bump_build_version.sh` increments it; the pipeline commits that file only after successful uploads. `MARKETING_VERSION` changes are a deliberate, separate commit.

## Mac specifics

- The Mac artifact is a signed `.pkg` exported with the App Store method; match must provide the `mac_installer_distribution` certificate.
- The app and the widget extension both need App Store provisioning profiles for macOS (`match AppStore com.kodalabs.app macos`, `match AppStore com.kodalabs.app.widgets macos`).
