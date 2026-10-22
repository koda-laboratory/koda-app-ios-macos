# Keychain, biometrics, and media

## Keychain

- `Keychain` (`Koda/Core/Security/`) and `KeychainStorableDataSource` (`Koda/Core/DataSources/Persistent/`) store the `UserSession` (`userId`, `accessToken`, `refreshToken`, `expiresAt`); `SessionRepositoryImpl` is the only consumer.
- Items use `kSecAttrAccessibleAfterFirstUnlock` so background sync, silent pushes, and intents can read tokens while the device is locked.
- Items live in the shared access group `$(TeamIdentifierPrefix)com.kodalabs.app` (`keychain-access-groups` in both app entitlements) so the app and its extensions share the session.
- On macOS every query sets `kSecUseDataProtectionKeychain = true` (iOS-style keychain inside the sandbox). Keep that platform difference inside the Keychain wrapper (`Core/Security/` or `Core/Platform/`).
- Unsigned builds (`CODE_SIGNING_ALLOWED=NO`) cannot use the access group (`errSecMissingEntitlement`); test Keychain behavior on signed builds.
- Never log stored values.

## Biometric lock (planned)

- `BiometricLockService` wraps `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` (Face ID on iPhone, Touch ID or the Mac password on macOS).
- It protects the UI only (lock on cold start and after more than 5 minutes in background); tokens are not biometric-protected.
- `NSFaceIDUsageDescription` lives in `Configuration/Info.plist` / `InfoPlist.xcstrings`.

## WebKit

- Use `WebView`/`WebPage` (SwiftUI) inside a `Common/Presentation/Web/` component when an in-app page is needed (for example the MCP connection instructions). Keep only `https` URLs in-app and hand other schemes to the system.

## AVKit

- Use `VideoPlayer`/`AVPlayer` with the view lifecycle; respect Reduce Motion and release the player on disappear.
