import Foundation

/// Data-protection class of the shared database.
///
/// iOS uses `completeUntilFirstUserAuthentication` so App Intents, silent pushes and `BGAppRefreshTask` can
/// write while the iPhone is locked. macOS has no per-file data protection classes for this use.
enum PlatformFileProtection {
    static func protectDirectory(at url: URL) {
        #if os(iOS)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        #endif
    }

    /// Protects the database and its WAL/SHM companions.
    static func protectDatabase(at url: URL) {
        #if os(iOS)
            for suffix in ["", "-wal", "-shm"] {
                let path = url.path + suffix
                guard FileManager.default.fileExists(atPath: path) else { continue }
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: path
                )
            }
        #endif
    }
}
