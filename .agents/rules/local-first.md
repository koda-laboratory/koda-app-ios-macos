---
description: Koda is local-first — repositories write GRDB and the outbox in one transaction and the UI never waits on the network
alwaysApply: true
---

# Local-first

The local GRDB database is the source of truth for the UI on iPhone and Mac. The network only synchronizes it. Implementation details live in the [`local-first-sync`](../skills/local-first-sync/SKILL.md) skill.

## Writes

- Product repositories write the local row **and** its outbox mutation in the **same GRDB transaction**. Never write one without the other, and never call the sync endpoints from a repository, use case, or ViewModel.
- Identifiers are client-generated UUIDs. Synced rows carry `household_id`, `updated_at`, `updated_by`, and `deleted_at` (tombstone); deletes are tombstones, not hard deletes.
- `shopping_entries` and `shopping_entry_items` also maintain `checked_at` and `name_updated_at`, because the server resolves them with per-field last-writer-wins.

## Reads

- The UI observes GRDB with `ValueObservation`, exposed upward as `AsyncStream` through repositories and observation use cases. Screens never show a spinner waiting for the network for data that exists locally, and never block on a request to render.
- Offline is a normal state: the app shows a discreet "Sin conexión · N cambios pendientes" indicator instead of errors.

## Sync

- Only the `SyncEngine` actor (planned in `Koda/Core/Sync/`) talks to `/sync/push` and `/sync/pull`. It is single-flight: push the outbox first, then pull from the stored cursor.
- Pull applies remote changes inside one transaction **without** generating outbox entries and advances `sync_state.cursor` in the same transaction.
- Server rejections are logged and the server version wins.

## Session and lifecycle

- Logout revokes the session, removes the device, and clears the Keychain **and** the local database.
- A failed refresh (`invalid_grant` or equivalent) forces login **without** deleting the local database or the outbox; pending changes sync after the next login.
- Biometric lock protects the UI only; tokens stay readable after first unlock so background sync, silent pushes, and intents keep working.

## Extensions, intents, and background

- The database lives in the App Group container (`group.com.kodalabs.app`) so the app, App Intents, and widgets share it. On iOS the file uses `completeUntilFirstUserAuthentication` protection so intents and background sync can write while the iPhone is locked.
- App Intents and widgets read and write only the local database through use cases and never call the network; they leave sync to the `SyncEngine`. Widgets never refresh tokens.
- After a pull that changed data, reload widget timelines (`WidgetCenter.shared.reloadAllTimelines()`).
