import Swinject

extension Assembly {
    final class Core: Swinject.Assembly {
        func assemble(container: Container) {
            registerInfrastructure(in: container)
            registerHTTP(in: container)
            registerSession(in: container)
            registerDatabase(in: container)
            registerSync(in: container)
            registerDevice(in: container)
            registerLock(in: container)
        }

        private func registerInfrastructure(in container: Container) {
            container.register(LoggerService.self) { _ in LoggerServiceImpl() }
                .inObjectScope(.container)

            container.register(KodaErrorCenter.self) { _ in KodaErrorCenter() }
                .inObjectScope(.container)

            container.register(VolatileDataSource.self) { _ in NSCacheVolatileDataSource() }
                .inObjectScope(.container)

            container.register(KeychainPersistentDataSource.self) { _ in KeychainStorableDataSource() }
                .inObjectScope(.container)
        }

        private func registerHTTP(in container: Container) {
            container.register(HTTPTransport.self) { _ in URLSessionHTTPTransport() }
                .inObjectScope(.container)

            container.register(HTTPLogging.self) { resolver in
                HTTPLoggerImpl(
                    configuration: .currentEnvironment,
                    loggerService: resolver.required(LoggerService.self)
                )
            }
            .inObjectScope(.container)

            container.register(HTTPRequestExecuting.self) { resolver in
                HTTPRequestExecutorImpl(
                    httpLogger: resolver.required(HTTPLogging.self),
                    transport: resolver.required(HTTPTransport.self)
                )
            }
            .inObjectScope(.container)

            container.register(HTTPSessionRecovery.self) { resolver in
                HTTPSessionRecoveryImpl(
                    refreshSessionUseCaseProvider: {
                        DependencyContainer.shared.required(RefreshSessionUseCase.self)
                    },
                    errorCenter: resolver.required(KodaErrorCenter.self),
                    loggerService: resolver.required(LoggerService.self)
                )
            }
            .inObjectScope(.container)

            container.register(HTTPService.self) { resolver in
                HTTPServiceImpl(
                    executor: resolver.required(HTTPRequestExecuting.self),
                    errorCenter: resolver.required(KodaErrorCenter.self),
                    sessionRecovery: resolver.required(HTTPSessionRecovery.self),
                    sessionExpiry: resolver.required(SessionService.self)
                )
            }
            .inObjectScope(.container)

            container.register(
                HTTPHeaderProvider.self,
                name: Assembly.supabaseHeaderProviderName
            ) { resolver in
                SupabaseHeaderProvider(sessionProvider: resolver.required(SessionService.self))
            }
            .inObjectScope(.container)
        }

        private func registerSession(in container: Container) {
            container.register(SessionRepository.self) { resolver in
                SessionRepositoryImpl(
                    persistentDataSource: resolver.required(KeychainPersistentDataSource.self),
                    volatileDataSource: resolver.required(VolatileDataSource.self)
                )
            }
            .inObjectScope(.container)

            container.register(SessionService.self) { resolver in
                SessionServiceImpl(
                    repository: resolver.required(SessionRepository.self),
                    errorCenter: resolver.required(KodaErrorCenter.self),
                    loggerService: resolver.required(LoggerService.self)
                )
            }
            .inObjectScope(.container)
        }

        private func registerDatabase(in container: Container) {
            container.register(AppDatabase.self) { resolver in
                do {
                    return try AppDatabase.makeShared()
                } catch {
                    // Never crash at launch: run on an empty in-memory store and report it.
                    resolver.required(LoggerService.self).fault("Unable to open the local database: \(error)")
                    do {
                        return try AppDatabase.makeInMemory()
                    } catch {
                        fatalError("Unable to create even an in-memory database: \(error)")
                    }
                }
            }
            .inObjectScope(.container)

            container.register(LocalMutationWriter.self) { _ in LocalMutationWriter() }
                .inObjectScope(.container)

            container.register(LocalDataRepository.self) { resolver in
                LocalDataRepositoryImpl(database: resolver.required(AppDatabase.self))
            }
            .inObjectScope(.container)

            container.register(MeRemoteDataSource.self) { resolver in
                MeRemoteDataSourceImpl(
                    httpService: resolver.required(HTTPService.self),
                    headerProvider: resolver.required(
                        HTTPHeaderProvider.self,
                        name: Assembly.supabaseHeaderProviderName
                    )
                )
            }
            .inObjectScope(.container)

            container.register(MeRepository.self) { resolver in
                MeRepositoryImpl(
                    remoteDataSource: resolver.required(MeRemoteDataSource.self),
                    database: resolver.required(AppDatabase.self)
                )
            }
            .inObjectScope(.container)
        }

        private func registerSync(in container: Container) {
            container.register(SyncLocalDataSource.self) { resolver in
                SyncLocalDataSourceImpl(database: resolver.required(AppDatabase.self))
            }
            .inObjectScope(.container)

            container.register(SyncRemoteDataSource.self) { resolver in
                SyncRemoteDataSourceImpl(
                    httpService: resolver.required(HTTPService.self),
                    headerProvider: resolver.required(
                        HTTPHeaderProvider.self,
                        name: Assembly.supabaseHeaderProviderName
                    )
                )
            }
            .inObjectScope(.container)

            container.register(SyncEngine.self) { resolver in
                let deviceRepository = resolver.required(DeviceRepository.self)
                return SyncEngineImpl(
                    localDataSource: resolver.required(SyncLocalDataSource.self),
                    remoteDataSource: resolver.required(SyncRemoteDataSource.self),
                    deviceID: { try? await deviceRepository.installationID() },
                    loggerService: resolver.required(LoggerService.self)
                )
            }
            .inObjectScope(.container)

            container.register(SyncScheduling.self) { resolver in
                let sessionService = resolver.required(SessionService.self)
                return SyncSchedulerImpl(
                    engine: resolver.required(SyncEngine.self),
                    localDataSource: resolver.required(SyncLocalDataSource.self),
                    reachability: NetworkPathReachability(),
                    widgetReloader: WidgetCenterTimelineReloader(),
                    backgroundRefresh: PlatformBackgroundRefreshScheduler(),
                    isSignedIn: { (try? await sessionService.current(errorHandling: .suppressed)) != nil },
                    loggerService: resolver.required(LoggerService.self)
                )
            }
            .inObjectScope(.container)

            container.register(ObserveSyncStatusUseCase.self) { resolver in
                ObserveSyncStatusUseCaseImpl(syncScheduler: resolver.required(SyncScheduling.self))
            }

            container.register(RequestSyncUseCase.self) { resolver in
                RequestSyncUseCaseImpl(syncScheduler: resolver.required(SyncScheduling.self))
            }
        }

        private func registerDevice(in container: Container) {
            container.register(DeviceRemoteDataSource.self) { resolver in
                DeviceRemoteDataSourceImpl(
                    httpService: resolver.required(HTTPService.self),
                    headerProvider: resolver.required(
                        HTTPHeaderProvider.self,
                        name: Assembly.supabaseHeaderProviderName
                    )
                )
            }
            .inObjectScope(.container)

            container.register(DeviceRepository.self) { resolver in
                DeviceRepositoryImpl(
                    remoteDataSource: resolver.required(DeviceRemoteDataSource.self),
                    persistentDataSource: resolver.required(KeychainPersistentDataSource.self)
                )
            }
            .inObjectScope(.container)

            container.register(RegisterDeviceUseCase.self) { resolver in
                RegisterDeviceUseCaseImpl(
                    deviceRepository: resolver.required(DeviceRepository.self),
                    sessionService: resolver.required(SessionService.self)
                )
            }
        }

        private func registerLock(in container: Container) {
            container.register(LockPreferencesDataSource.self) { _ in UserDefaultsLockPreferencesDataSource() }
                .inObjectScope(.container)

            container.register(BiometricLockService.self) { resolver in
                BiometricLockServiceImpl(
                    authenticator: LocalAuthenticationAuthenticator(),
                    preferences: resolver.required(LockPreferencesDataSource.self)
                )
            }
            .inObjectScope(.container)

            container.register(ObserveAppLockUseCase.self) { resolver in
                ObserveAppLockUseCaseImpl(lockService: resolver.required(BiometricLockService.self))
            }

            container.register(UnlockAppUseCase.self) { resolver in
                UnlockAppUseCaseImpl(lockService: resolver.required(BiometricLockService.self))
            }

            container.register(UpdateLockPolicyUseCase.self) { resolver in
                UpdateLockPolicyUseCaseImpl(lockService: resolver.required(BiometricLockService.self))
            }
        }
    }
}
