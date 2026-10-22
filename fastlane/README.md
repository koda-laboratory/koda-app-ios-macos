# fastlane de Koda

Firma y distribución de Koda para iPhone y Mac. **Solo TestFlight**, grupo interno `House`: no hay lane de App Store, `Deliverfile`, metadatos ni Slack.

Las App IDs (`com.kodalabs.app` con Push y App Groups, `com.kodalabs.app.widgets` con App Groups), el App Group `group.com.kodalabs.app` y el registro de App Store Connect (iOS + macOS) ya existen. Las lanes no los crean: solo obtienen o crean certificados y perfiles con match.

## Puesta en marcha

```sh
bundle install
cp fastlane/.env.example fastlane/.env   # y rellenar los valores (fichero ignorado por Git)
```

Variables (`fastlane/.env` en local, secrets en CI):

| Variable | Contenido |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID de la API key de App Store Connect (rol App Manager) |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Contenido del `.p8` en base64 (`base64 -i AuthKey_XXXX.p8 \| tr -d '\n'`) |
| `MATCH_PASSWORD` | Contraseña del repo `koda-laboratory/mobile-macos-ios-certs` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 de `usuario-github:token` con lectura del repo de certificados |
| `MATCH_KEYCHAIN_PASSWORD` | Contraseña del keychain temporal (solo CI) |
| `FASTLANE_COMMIT_AND_PUSH` | Opcional. `true` para que `pipeline_build_upload` haga commit y push del build |

## Lanes

Todas existen en `ios` y en `mac` (`bundle exec fastlane <plataforma> <lane>`):

| Lane | Qué hace |
| --- | --- |
| `test` | Ejecuta `KodaTests` (iPhone 17 en el simulador, o este Mac sin firma) |
| `fetch_certificates_development` / `fetch_certificates_appstore` | Instala certificados y perfiles con match (solo lectura en CI) |
| `update_certificates_development` / `update_certificates_appstore` | Crea o renueva certificados y perfiles en el repo de match. En `mac appstore` incluye `mac_installer_distribution` |
| `register_development_device name:<n> udid:<u>` | Registra un iPhone o un Mac (Provisioning UDID) y regenera los perfiles de desarrollo |
| `build_sign` | Archiva `Release` y exporta `.ipa` (iOS) o `.pkg` firmado con Mac Installer Distribution (macOS) en `.build/fastlane/` |
| `upload_testflight` | Sube el artefacto, espera al procesado y lo asigna al grupo interno `House` |
| `pipeline_build_upload` | Sube el build en `Configuration/version.xcconfig`, compila, sube y hace commit. Opciones `bump_version:false` y `commit_version:false` |
| `clean` | Borra `.build/DerivedData` y `.build/fastlane` |

Para subir las dos plataformas con el **mismo** número de build usa `scripts/pipeline_build_upload.sh` (admite `--resume`). La GitHub Action mensual (`.github/workflows/testflight-monthly.yml`) hace lo mismo en CI.

## Perfiles

match nombra los perfiles `match Development|AppStore <bundle id>` en iOS y con el sufijo ` macos` en macOS. `Configuration/Koda.xcconfig` los selecciona por configuración (`Debug` → Development, `Release` → AppStore) y SDK, así que Xcode y fastlane usan la misma firma manual.
