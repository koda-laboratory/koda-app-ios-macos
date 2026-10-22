import Foundation

/// Facts about this build that the device registration sends.
struct DeviceEnvironment: Sendable, Equatable {
    /// `ios` | `macos`.
    let platform: String
    /// `sandbox` | `production`, from the `APNS_ENVIRONMENT` build setting.
    let apnsEnvironment: String
    let appVersion: String

    static var current: DeviceEnvironment {
        DeviceEnvironment(
            platform: PlatformInfo.platformName,
            apnsEnvironment: PlatformInfo.apnsEnvironment,
            appVersion: PlatformInfo.appVersion
        )
    }
}

actor DeviceRepositoryImpl: DeviceRepository {
    private struct StoredInstallationID: Storable {
        static let storageIdentifier = "installation-id"
        static let currentIdentifier = "current"

        let id: String
        let value: String
    }

    // MARK: - Properties

    private let remoteDataSource: any DeviceRemoteDataSource
    private let persistentDataSource: any KeychainPersistentDataSource
    private let environment: DeviceEnvironment
    private var cachedID: String?

    // MARK: - Lifecycle

    init(
        remoteDataSource: any DeviceRemoteDataSource,
        persistentDataSource: any KeychainPersistentDataSource,
        environment: DeviceEnvironment = .current
    ) {
        self.remoteDataSource = remoteDataSource
        self.persistentDataSource = persistentDataSource
        self.environment = environment
    }

    // MARK: - Public Methods

    func installationID() async throws(KodaError) -> String {
        if let cachedID { return cachedID }
        do {
            if let stored = try await persistentDataSource.read(
                StoredInstallationID.self,
                id: StoredInstallationID.currentIdentifier
            ) {
                cachedID = stored.value
                return stored.value
            }
            let value = UUID().uuidString.lowercased()
            try await persistentDataSource.update(
                StoredInstallationID(id: StoredInstallationID.currentIdentifier, value: value)
            )
            cachedID = value
            return value
        } catch {
            throw KodaErrorMapper.map(error)
        }
    }

    func register(apnsToken: Data) async throws(KodaError) {
        let body = DeviceRegistrationRequestDTO(
            id: try await installationID(),
            apnsToken: apnsToken.map { String(format: "%02x", $0) }.joined(),
            platform: environment.platform,
            apnsEnv: environment.apnsEnvironment,
            appVersion: environment.appVersion
        )
        try await remoteDataSource.register(body)
    }

    func unregister() async throws(KodaError) {
        do {
            try await remoteDataSource.unregister(id: try await installationID())
        } catch  where error.type == .notFound {
            // Never registered (no APNs token yet): nothing to remove.
        }
    }
}
