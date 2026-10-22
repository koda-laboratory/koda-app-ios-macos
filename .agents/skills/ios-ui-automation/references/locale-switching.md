# Locale switching

Koda supports English and Spanish (`Localizable.xcstrings`).

## iPhone simulator (launch arguments)

```bash
xcrun simctl terminate <IOS_UDID> com.kodalabs.app
xcrun simctl launch <IOS_UDID> com.kodalabs.app -AppleLanguages '(es)' -AppleLocale es_ES
```

| Language | `AppleLanguages` | `AppleLocale` |
| --- | --- | --- |
| English | `(en)` | `en_US` |
| Spanish | `(es)` | `es_ES` |

In Maestro, pass the same arguments through `launchApp` → `arguments`.

## Mac

Set the scheme's App Language (Run → Options) or launch the built app with the same arguments:

```bash
open -a <path to Koda.app> --args -AppleLanguages '(es)' -AppleLocale es_ES
```

## Screenshots

Capture each state once per locale on an iPhone and on the Mac with the same test data. Keep them out of Git. Restore the original language afterwards.
