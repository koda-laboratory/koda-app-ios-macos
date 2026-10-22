import Foundation

/// What the shared offline indicator renders ("Sin conexión · 3 cambios pendientes").
struct SyncStatus: Sendable, Equatable {
    var isOnline: Bool
    var pendingChanges: Int
    var isSyncing: Bool
    var lastSyncAt: Date?
    var lastErrorType: KodaErrorType?

    static let initial = SyncStatus(isOnline: true, pendingChanges: 0, isSyncing: false)
}

/// Why a sync was requested.
enum SyncTrigger: String, Sendable, Equatable {
    case launch
    case foreground
    case reconnect
    case localChange
    case silentPush
    case backgroundRefresh
    case manual
    case login
}

/// Result reported to the system for background work (silent push, `BGAppRefreshTask`).
enum SyncOutcome: Sendable, Equatable {
    case newData
    case noData
    case failed
    case skipped
}
