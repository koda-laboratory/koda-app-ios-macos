# Repository and DataSource Patterns

Session/auth types live in `Koda/Core/`. Feature examples (`ShoppingRepositoryImpl`, …) are the planned shape; the GRDB layer (`Koda/Core/Database/`) is not implemented yet.

## Remote DataSource: one provider boundary

A remote data source injects only `HTTPService`, executes typed requests, and returns DTOs:

```swift
final class AuthRemoteDataSourceImpl: AuthRemoteDataSource, Sendable {
    private let httpService: any HTTPService

    init(httpService: any HTTPService) {
        self.httpService = httpService
    }

    func refresh(refreshToken: String) async throws(KodaError) -> SupabaseSessionDTO {
        try await httpService.execute(AuthAPI.refresh(refreshToken: refreshToken))
    }
}
```

Request construction lives in `Koda/Core/Api/Providers/Supabase/AuthAPI.swift`. The data source does not save sessions, map users, choose UI errors, or implement fallback.

## Repository: DTO-to-domain boundary

```swift
func refresh(_ session: UserSession) async throws(KodaError) -> UserSession {
    UserSession(fromDTO: try await remoteDataSource.refresh(refreshToken: session.refreshToken))
}
```

The repository exposes domain types. Use cases never see GoTrue DTOs.

## Local-first product repository (GRDB + outbox)

```swift
func toggle(entryID: UUID, checked: Bool, by userID: UUID) async throws(KodaError) -> ShoppingEntry {
    try await database.write { db in
        var record = try ShoppingEntryRecord.fetchOne(db, key: entryID).orThrow(.notFound)
        record.checked = checked
        record.checkedAt = .now
        record.updatedBy = userID
        try record.update(db)
        try OutboxRecord.upsert(table: .shoppingEntries, row: record, clientTimestamp: .now).insert(db)
        return ShoppingEntry(record: record)
    }
}

func observeList() -> AsyncStream<[ShoppingEntry]> {
    database.observe { db in try ShoppingEntryRecord.visible().fetchAll(db) }
        .map { $0.map(ShoppingEntry.init(record:)) }
}
```

- The row and the outbox entry are written in the **same transaction**.
- The repository never calls `/sync/push`; the `SyncEngine` drains the outbox.
- Pull-side application (`SyncEngine`) writes rows without creating outbox entries.

## Multi-tier cache repository

Reference: `Koda/Core/Repositories/SessionRepositoryImpl.swift`

1. Read the volatile cache.
2. Fall back to the Keychain (`KeychainStorableDataSource`, shared access group; data-protection keychain on macOS).
3. Warm the volatile cache after a persistent hit.
4. Update/delete both stores together.

The private `Storable` wrapper is a persistence representation and remains inside the implementation. Callers receive `UserSession`.

## Placement decisions

| Situation | Placement |
| --- | --- |
| One feature, local tables | `Features/<Feature>/Repositories` + shared database access from `Core/Database` |
| One feature, one remote endpoint | `Features/<Feature>/DataSources` and `Repositories` |
| Cross-feature storage/provider abstraction | `Core/DataSources` or `Core/Repositories` |
| Supabase request declarations | `Core/Api/Providers/Supabase/` |
| Persistence-only representation | Private inside the repository/DataSource or `Core/Database/Records` |

## Anti-patterns

```swift
// Wrong: repository waits for the network before reflecting a local change.
try await httpService.execute(KodaAPI.push(mutation))
try await database.write { ... }

// Wrong: row written without its outbox entry (or in a separate transaction).
try await database.write { db in try record.update(db) }
try await database.write { db in try outbox.insert(db) }

// Wrong: repository leaks transport or storage data.
func refresh() async -> SupabaseSessionDTO
func entries() async -> [ShoppingEntryRecord]

// Wrong: a DataSource wrapping another DataSource.
final class ShoppingLocalDataSourceImpl { let database: AppDatabase; let keychain: KeychainPersistentDataSource }
```

Also avoid presentation strings, toast decisions, or view state in the repository, and undocumented ordering between local and remote writes.
