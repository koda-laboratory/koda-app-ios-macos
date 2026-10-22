# Koda para iPhone y Mac

App nativa de Koda, la app privada de casa. Su primer módulo, **Comidita**, cubre recetas, planning de comidas y lista de la compra. Swift 6 y SwiftUI en **un único target multiplataforma**: iPhone (iOS 26.5+) y Mac (macOS 26.5+, SwiftUI nativo, no Catalyst). El backend (Supabase) vive en `../koda-backend` y el plan completo en `../PLAN.md`.

## Configuración

- Bundle ids `com.kodalabs.app` (app, iOS + macOS) y `com.kodalabs.app.widgets`, App Group `group.com.kodalabs.app`, team `MUDCX7X324`.
- **Un solo entorno**: un proyecto de Supabase (`koda`), un scheme compartido `Koda` y las configuraciones `Debug` y `Release`.
- `Koda.xcodeproj` con los targets `Koda` (iPhone + Mac), `KodaWidgets` (widget "Hoy", iPhone + Mac) y `KodaTests` (Swift Testing), con carpetas sincronizadas. Dependencias SPM: Swinject y GRDB.swift (`Package.resolved` versionado).
- `Configuration/`: `Koda.xcconfig` (valores públicos: URL de Supabase, ids, firma), `version.xcconfig` (única fuente de versión), `Info.plist` y los entitlements por SDK (`Koda-iOS`, `Koda-macOS`, `KodaWidgets`).
- Secretos fuera de Git: la publishable key de Supabase va en `Configuration/Koda.private.xcconfig` (plantilla `Koda.private.xcconfig.example`) y los de fastlane en `fastlane/.env` (plantilla `fastlane/.env.example`).

> **Pendiente**: sustituir `<project-ref>` en `SUPABASE_URL` (`Configuration/Koda.xcconfig`) cuando exista el proyecto de Supabase.

## Puesta en marcha

1. `brew bundle` (SwiftLint).
2. `bundle install` (fastlane y plugins, Ruby de `.ruby-version`).
3. `scripts/install-git-hooks.sh` (activa `.githooks/pre-commit`, que valida el formato con `swift format lint --strict`).
4. Copiar `Configuration/Koda.private.xcconfig.example` a `Configuration/Koda.private.xcconfig` y poner la publishable key.
5. Para firmar en dispositivo: `bundle exec fastlane ios fetch_certificates_development` y `bundle exec fastlane mac fetch_certificates_development`.
6. Abrir `Koda.xcodeproj` y ejecutar el scheme `Koda` en un iPhone o en "My Mac".

Sin firma (como en CI):

```sh
xcodebuild -project Koda.xcodeproj -scheme Koda -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Koda.xcodeproj -scheme Koda -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Koda.xcodeproj -scheme Koda -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Estructura

`Koda/` sigue la arquitectura de Gotty: `App` (punto de entrada y `AppDelegate` por plataforma), `Assembly` (Swinject), `Common` (MVI, design system en `Theme`, componentes), `Core` (HTTP + Supabase, recuperación de sesión single-flight, errores `KodaError`, Keychain, sesión, navegación y `Platform`, el único sitio con `#if os` además de `App`), `Extensions`, `Features` y `Resources` (`Localizable.xcstrings`, `InfoPlist.xcstrings`, assets). Vista → ViewModel → UseCase → Repository → DataSource, y local-first con GRDB y outbox (a partir de la Fase 2).

## Calidad y agentes

`scripts/swiftlint.sh` (también fase de build del target) y `swift format` con `.swift-format`. `AGENTS.md` (enlazado como `CLAUDE.md`) define invariantes, mapa del proyecto, reglas y skills de `.agents/`, compartidas con Claude, Codex, Cursor, Windsurf y Continue mediante enlaces simbólicos. `.mcp.json` y `.codex/config.toml` configuran el MCP de Xcode (`xcrun mcpbridge`).

## Versión y distribución

Solo **TestFlight**, grupo interno `House`. La versión vive en `Configuration/version.xcconfig`; `scripts/bump_build_version.sh` incrementa el build. Lanes y variables en [`fastlane/README.md`](fastlane/README.md). `scripts/pipeline_build_upload.sh [--resume]` sube iOS y macOS con el mismo número de build.

## GitHub Actions

- `ci.yml`: en cada push a `main` y en cada PR compila y ejecuta los tests en iOS y macOS sin firma, y valida el formato.
- `testflight-monthly.yml`: el día 1 de cada mes a las 04:17 UTC (o a mano con *Run workflow*) sube un build nuevo de iOS y de macOS a TestFlight, lo asigna al grupo `House` y hace commit `chore: bump build to N [skip ci]` en `main`. Así siempre hay un build sin caducar.

Secrets del repositorio (Settings → Secrets and variables → Actions):

| Secret | Contenido |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID de la API key de App Store Connect (App Manager) |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | `.p8` en base64 (`base64 -i AuthKey_XXXX.p8 \| tr -d '\n'`) |
| `MATCH_PASSWORD` | Contraseña del repo de certificados `koda-laboratory/mobile-macos-ios-certs` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 de `usuario-github:token` con lectura de ese repo |
| `MATCH_KEYCHAIN_PASSWORD` | Cualquier contraseña aleatoria para el keychain temporal de CI |
| `SUPABASE_PUBLISHABLE_KEY` | Opcional: publishable key (`sb_publishable_…`) que se escribe en `Koda.private.xcconfig` antes de archivar |

El workflow necesita permiso de escritura en `contents` (ya declarado) para hacer push del commit del build; si `main` está protegida, permite que `github-actions[bot]` haga push.
