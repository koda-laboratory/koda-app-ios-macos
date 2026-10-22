---
name: ios-deployment
description: Build, sign, version, and upload Koda for iPhone and Mac through the repository's fastlane setup — match certificates (iOS + macOS, including the Mac installer certificate), TestFlight internal distribution to the "House" group, the monthly GitHub Action, and CI. Use for release builds, signing and provisioning, device registration, version bumps, or CI/CD. Not for day-to-day feature validation (development rule) and never as a side effect of implementation work.
---

# Deployment (iOS + macOS)

Koda is distributed **only** through TestFlight to the internal group "House". There is no App Store release, `Deliverfile`, store metadata, or Slack.

## Sources of truth

- Version: `Configuration/version.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`), included by `Configuration/Koda.xcconfig` and read by fastlane. Helpers: `scripts/get_marketing_version.sh`, `scripts/get_build_version.sh`, `scripts/bump_build_version.sh`. The same build number is used for the iOS and macOS uploads.
- Identity: product `Koda`, bundle ids `com.kodalabs.app` (app, iOS + macOS) and `com.kodalabs.app.widgets`, App Group `group.com.kodalabs.app`, team `MUDCX7X324` (`Koda.xcconfig`, `fastlane/Appfile`, `fastlane/Matchfile`).
- One scheme `Koda`, configurations `Debug` (development) and `Release` (TestFlight archives).
- Entitlements per SDK: `Configuration/Koda-iOS.entitlements`, `Configuration/Koda-macOS.entitlements`, `Configuration/KodaWidgets.entitlements`.
- Signing: fastlane match, git storage `https://github.com/koda-laboratory/mobile-macos-ios-certs.git` (private, own password), types `development` and `appstore`, platforms `ios` and `macos`, plus `additional_cert_types: ["mac_installer_distribution"]` to sign the Mac `.pkg`.
- Secrets: the ignored `fastlane/.env` (see `fastlane/.env.example` for names) or the environment — App Store Connect API key (`APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`), `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION`, `MATCH_KEYCHAIN_PASSWORD` (CI only); the Supabase publishable key in the ignored `Configuration/Koda.private.xcconfig`. Never print or read secret values into the conversation.
- Ruby: `.ruby-version`, `Gemfile` (fastlane, plugins from `fastlane/Pluginfile`), `Gemfile.lock`. Always run `bundle exec fastlane <platform> <lane>` from the repository root.

## Reference

Read [cicd.md](references/cicd.md) before configuring CI, changing lanes, or running a release pipeline.

## Lanes (`platform :ios` and `platform :mac`)

| Lane | Effect |
| --- | --- |
| `test` | run `KodaTests` (iOS simulator / macOS) |
| `fetch_certificates_development` / `fetch_certificates_appstore` | install certificates and profiles with match (read-only in CI) |
| `update_certificates_development` / `update_certificates_appstore` | refresh certificates and profiles through App Store Connect |
| `register_development_device name:<n> udid:<u>` | register an iPhone or Mac and refresh the development profiles |
| `build_sign` | fetch App Store certificates and archive `Release` → `.ipa` (iOS) or `.pkg` (macOS) into `.build/fastlane` |
| `upload_testflight` | upload the artifact, wait for processing, and distribute it to the internal group "House" |
| `pipeline_build_upload` | bump `CURRENT_PROJECT_VERSION` (unless disabled), build, upload, and optionally commit the version file |
| `clean` | remove `.build/DerivedData` and `.build/fastlane` |

`scripts/pipeline_build_upload.sh` runs the iOS and Mac pipelines with one shared build bump and commits `Configuration/version.xcconfig` only after both uploads succeed.

## Rules

- Never run upload, pipeline, or certificate-update lanes unless the user explicitly asks for that action in this session.
- Keep the bundle ids, team, App Group, and signing identities unchanged. The App IDs, App Group, and App Store Connect record already exist; lanes never create them (no `produce`).
- TestFlight builds expire after 90 days; the monthly GitHub Action (`.github/workflows/testflight-monthly.yml`) keeps a valid build. Internal testers must be members of the App Store Connect team.
- Never commit `fastlane/.env`, `fastlane/report.xml`, API keys, `.p8` files, certificates, provisioning profiles, `.ipa`, or `.pkg`.

## Workflow

1. Confirm the platform(s), the version, and that the user authorized publication.
2. Run the `development` validation (iPhone + Mac builds) and `KodaTests`.
3. Run the requested lane; read the output and stop on the first error.
4. Report the version, platform, lane, artifact path, TestFlight processing/distribution result, and any version commit.
