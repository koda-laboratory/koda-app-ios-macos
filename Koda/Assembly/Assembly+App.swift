extension Assembly {
    /// The app-wide lifecycle coordinator, owned by the platform app delegate.
    static func makeAppLifecycleCoordinator(
        container: DependencyContainer = .shared
    ) -> AppLifecycleCoordinator {
        AppLifecycleCoordinator(
            restoreSession: container.required(RestoreSessionUseCase.self),
            login: container.required(LoginUseCase.self),
            logout: container.required(LogoutUseCase.self),
            expireSession: container.required(ExpireSessionUseCase.self),
            refreshHousehold: container.required(RefreshHouseholdUseCase.self),
            registerDevice: container.required(RegisterDeviceUseCase.self),
            syncScheduler: container.required(SyncScheduling.self),
            widgetMenu: container.required(WidgetMenuService.self),
            intentIndexing: IntentIndexingService(
                observeRecipes: container.required(ObserveRecipeCatalogUseCase.self),
                observeProducts: container.required(ObserveProductsUseCase.self),
                loggerService: container.required(LoggerService.self)
            ),
            lockService: container.required(BiometricLockService.self),
            errorCenter: container.required(KodaErrorCenter.self),
            loggerService: container.required(LoggerService.self),
            registerForRemoteNotifications: { PlatformRemoteNotifications.register() }
        )
    }
}
