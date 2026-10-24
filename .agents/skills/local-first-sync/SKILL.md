---
name: local-first-sync
description: Implement Koda's local-first data path — GRDB AppDatabase in the App Group, migrations and records, writes that enqueue the outbox in the same transaction, ValueObservation streams, and the SyncEngine (push outbox → /sync/push, pull by cursor ← /sync/pull) with its triggers and conflict rules. Use when adding a synced table, writing a repository that mutates product data, touching the outbox or sync, or debugging offline/pending-sync behavior. Not for auth endpoints (supabase-api) or APNs registration (push-notifications).
---

# Local-first sync

> Status: implemented (Phase 2 of `../PLAN.md`). `Koda/Core/Database/` holds `AppDatabase` (+ `Migrations`), `SyncedTable`, `Records/`, `SyncRowCodec` and the single write path `LocalMutationWriter` (row + outbox in the caller's transaction, tombstones with local cascade, shopping `checked_at`/`name_updated_at`); `Koda/Core/DataSources/Sync/` holds the outbox/cursor/pull application (`SyncLocalDataSource`, with rebase of pending changes on pulled rows) and the HTTP side; `Koda/Core/Sync/` holds `SyncEngine` and `SyncScheduler`. The backend side is owned by `../koda-backend` (`apply_mutations`, `server_seq`). Do not invent contract details beyond what is written here and in the backend; report gaps.

Read the `local-first` and `architecture` rules first.

## Database

- `AppDatabase` wraps a GRDB `DatabasePool` (WAL) stored in the App Group container `group.com.kodalabs.app`, shared by the app, App Intents, and widgets on iPhone and Mac.
- iOS file protection `completeUntilFirstUserAuthentication` so intents and background sync can write while the iPhone is locked.
- Schema changes are additive GRDB migrations registered in order; never edit a shipped migration.
- Local tables mirror the synced server tables (`stores`, `products`, `product_stores`, `recipes`, `recipe_ingredients`, `recipe_components`, `recipe_photos`, `meal_plan_drafts`, `meal_plan_entries`, `consumptions`, `shopping_entries`, `shopping_entry_items`, …) plus:

```text
outbox(id, table, row_id, op, fields_json, client_ts, attempts, last_error)
sync_state(cursor, last_sync_at)
pending_image_uploads(storage_path, created_at, attempts, last_error)
```

Recipe images are not synced through the outbox: `recipe_photos` rows and `recipes.image_path` sync normally, while the bytes go to the private Storage bucket `recipe-images` (`<household>/<recipe>/<uuid>.jpg`). `RecipePhotoRepository` writes the file to the App Group (`RecipeImages/`), the rows and a `pending_image_uploads` entry in one step; `RecipeImageUploadService` uploads the queue when online; `RecipeImageRepository.imageData` reads from disk or downloads once and keeps the file.

- Synced rows carry `id` (client UUID), `household_id`, `created_at`, `updated_at`, `updated_by`, `deleted_at` (tombstone). `server_seq` is server-only and drives the pull cursor.

## Writing (repositories)

```swift
try await database.write { db in
    try record.save(db)                                  // row
    try OutboxRecord(table: .recipes, rowID: record.id,  // mutation, same transaction
                     op: .upsert, fields: record.syncFields, clientTimestamp: now).insert(db)
}
```

- Row and outbox entry in **one transaction**; deletes set `deleted_at` and enqueue `op: delete`.
- Coalescing several pending upserts for the same row is allowed when it preserves the latest fields and `client_ts`.
- `shopping_entries`/`shopping_entry_items`: update `checked_at` when `checked` changes and `name_updated_at` when name/quantity/unit change.
- Never call the network from a repository; optionally notify the `SyncScheduler` (debounced) after the commit.

## Reading

Repositories expose `ValueObservation` as `AsyncStream<[DomainModel]>`, filtering out tombstoned rows. The UI never waits for the network.

## Sync contract (Edge Function `api`)

```text
POST /functions/v1/api/sync/push
  { device_id, mutations: [{ table, id, op: "upsert" | "delete", fields, client_ts }] }
  → { applied, rejected, cursor }

GET /functions/v1/api/sync/pull?cursor=N&limit=500
  → { changes: { <table>: [rows…] }, cursor, has_more }
```

Both use the user JWT (RLS applies). Treat the backend repository as the source of truth for field names.

## SyncEngine (actor, single-flight)

1. **Push**: read the outbox in batches of **100**, send, delete applied entries, record rejected ones (`attempts`, `last_error`) and let the server version win on the next pull.
2. **Pull**: loop from `sync_state.cursor` while `has_more`; apply each page in **one transaction without generating outbox entries**, upsert rows, apply tombstones, and advance the cursor in the same transaction.
3. After a pull with changes: reindex App Intents entities and `WidgetCenter.shared.reloadAllTimelines()`.
4. Concurrent triggers join the running sync instead of starting another one.
5. Network/auth failures leave the outbox intact; a forced re-login never clears it.

## Conflict rules (server-side, mirrored when applying pulls)

- Default: last-writer-wins per row by `client_ts`.
- `shopping_entries` and `shopping_entry_items`: last-writer-wins **per field** — `checked` by `checked_at`, name/quantity by `name_updated_at`.
- A delete (tombstone) wins over any earlier update.
- Tombstones older than 30 days are purged by the backend `keepalive`; a client whose cursor is older must do a full resync (report if the backend contract does not define it).

## Triggers

App launch, return to foreground, network regained (`NWPathMonitor`), after a local write (2 s debounce), silent push (see `push-notifications`), `BGAppRefreshTask` on iOS, and pull-to-refresh. On macOS: silent push while running and sync on activation.

## UI status

A discreet shared indicator, for example "Sin conexión · 3 cambios pendientes", derived from reachability and the outbox count. No per-screen network spinners.

## Testing

- In-memory `DatabaseQueue` with the real migrations.
- Repository writes produce exactly one outbox entry in the same transaction (roll back on failure).
- `SyncEngine` with a fake `HTTPTransport`: batching, rejected mutations, pull pagination, tombstones, cursor advance, no outbox from pulls, single-flight under concurrent triggers.
