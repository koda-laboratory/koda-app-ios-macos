// MARK: - ViewModels

extension Assembly {
    static func makeShellViewModel(container: DependencyContainer = .shared) -> ShellViewModel {
        ShellViewModel(
            observeSyncStatus: container.required(ObserveSyncStatusUseCase.self),
            observeHousehold: container.required(ObserveHouseholdUseCase.self)
        )
    }

    static func makeProfileViewModel(container: DependencyContainer = .shared) -> ProfileViewModel {
        ProfileViewModel(
            useCases: ProfileViewModel.UseCases(
                observeHousehold: container.required(ObserveHouseholdUseCase.self),
                observeSyncStatus: container.required(ObserveSyncStatusUseCase.self),
                updateSettings: container.required(UpdateHouseholdSettingsUseCase.self),
                getLockPolicy: container.required(GetLockPolicyUseCase.self),
                updateLockPolicy: container.required(UpdateLockPolicyUseCase.self),
                requestSync: container.required(RequestSyncUseCase.self),
                logout: container.required(LogoutUseCase.self)
            )
        )
    }

    static func makeTodayViewModel(container: DependencyContainer = .shared) -> TodayViewModel {
        TodayViewModel(
            useCases: TodayViewModel.UseCases(
                observeHousehold: container.required(ObserveHouseholdUseCase.self),
                observeTodayMeals: container.required(ObserveTodayMealsUseCase.self),
                observeFrozenItems: container.required(ObserveFrozenItemsUseCase.self),
                observeShoppingList: container.required(ObserveShoppingListUseCase.self),
                observePendingDrafts: container.required(ObservePendingDraftsUseCase.self),
                observeRecipeCatalog: container.required(ObserveRecipeCatalogUseCase.self),
                skipMeal: container.required(SkipMealUseCase.self),
                resolveFrozenItem: container.required(ResolveFrozenItemUseCase.self)
            )
        )
    }
}
