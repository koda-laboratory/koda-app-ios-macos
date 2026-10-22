import Swinject

extension Assembly {
    final class Auth: Swinject.Assembly {
        func assemble(container: Container) {
            container.register(AuthRemoteDataSource.self) { resolver in
                AuthRemoteDataSourceImpl(
                    httpService: resolver.required(HTTPService.self),
                    headerProvider: resolver.required(
                        HTTPHeaderProvider.self,
                        name: Assembly.supabaseHeaderProviderName
                    )
                )
            }
            .inObjectScope(.container)

            container.register(AuthRepository.self) { resolver in
                AuthRepositoryImpl(remoteDataSource: resolver.required(AuthRemoteDataSource.self))
            }
            .inObjectScope(.container)

            container.register(RefreshSessionUseCase.self) { resolver in
                RefreshSessionUseCaseImpl(
                    authRepository: resolver.required(AuthRepository.self),
                    sessionService: resolver.required(SessionService.self)
                )
            }

            container.register(LoginUseCase.self) { resolver in
                LoginUseCaseImpl(
                    authRepository: resolver.required(AuthRepository.self),
                    sessionService: resolver.required(SessionService.self),
                    meRepository: resolver.required(MeRepository.self),
                    localDataRepository: resolver.required(LocalDataRepository.self)
                )
            }

            container.register(RestoreSessionUseCase.self) { resolver in
                RestoreSessionUseCaseImpl(sessionService: resolver.required(SessionService.self))
            }

            container.register(LogoutUseCase.self) { resolver in
                LogoutUseCaseImpl(
                    syncScheduler: resolver.required(SyncScheduling.self),
                    deviceRepository: resolver.required(DeviceRepository.self),
                    authRepository: resolver.required(AuthRepository.self),
                    sessionService: resolver.required(SessionService.self),
                    localDataRepository: resolver.required(LocalDataRepository.self),
                    lockService: resolver.required(BiometricLockService.self)
                )
            }

            container.register(ExpireSessionUseCase.self) { resolver in
                ExpireSessionUseCaseImpl(
                    syncScheduler: resolver.required(SyncScheduling.self),
                    sessionService: resolver.required(SessionService.self)
                )
            }

            container.register(RefreshHouseholdUseCase.self) { resolver in
                RefreshHouseholdUseCaseImpl(meRepository: resolver.required(MeRepository.self))
            }

            container.register(ObserveHouseholdUseCase.self) { resolver in
                ObserveHouseholdUseCaseImpl(meRepository: resolver.required(MeRepository.self))
            }

            container.register(UpdateHouseholdSettingsUseCase.self) { resolver in
                UpdateHouseholdSettingsUseCaseImpl(meRepository: resolver.required(MeRepository.self))
            }
        }
    }
}

// MARK: - ViewModels

extension Assembly {
    static func makeLoginViewModel(container: DependencyContainer = .shared) -> LoginViewModel {
        LoginViewModel(login: container.required(LoginUseCase.self))
    }

    static func makeLockViewModel(container: DependencyContainer = .shared) -> LockViewModel {
        LockViewModel(
            observeLock: container.required(ObserveAppLockUseCase.self),
            unlockApp: container.required(UnlockAppUseCase.self),
            unlockReason: String(localized: "lock.reason")
        )
    }
}
