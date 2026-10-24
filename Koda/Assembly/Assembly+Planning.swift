import Foundation
import Swinject

extension Assembly {
    final class Planning: Swinject.Assembly {
        func assemble(container: Container) {
            container.register(PlanningRemoteDataSource.self) { resolver in
                PlanningRemoteDataSourceImpl(
                    httpService: resolver.required(HTTPService.self),
                    headerProvider: resolver.required(
                        HTTPHeaderProvider.self,
                        name: Assembly.supabaseHeaderProviderName
                    )
                )
            }
            .inObjectScope(.container)

            container.register(PlanningRepository.self) { resolver in
                PlanningRepositoryImpl(
                    database: resolver.required(AppDatabase.self),
                    writer: resolver.required(LocalMutationWriter.self),
                    remoteDataSource: resolver.required(PlanningRemoteDataSource.self)
                )
            }
            .inObjectScope(.container)

            container.register(WidgetMenuService.self) { resolver in
                WidgetMenuServiceImpl(
                    planningRepository: resolver.required(PlanningRepository.self),
                    shoppingRepository: resolver.required(ShoppingRepository.self),
                    meRepository: resolver.required(MeRepository.self),
                    widgetMenuRepository: resolver.required(WidgetMenuRepository.self)
                )
            }
            .inObjectScope(.container)

            container.register(ObserveTodayMealsUseCase.self) { resolver in
                ObserveTodayMealsUseCaseImpl(planningRepository: resolver.required(PlanningRepository.self))
            }
            container.register(ObserveWeekPlanUseCase.self) { resolver in
                ObserveWeekPlanUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(PlanMealUseCase.self) { resolver in
                PlanMealUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(UpdatePlannedMealUseCase.self) { resolver in
                UpdatePlannedMealUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(SkipMealUseCase.self) { resolver in
                SkipMealUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(RemovePlannedMealUseCase.self) { resolver in
                RemovePlannedMealUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(LogConsumptionUseCase.self) { resolver in
                LogConsumptionUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(RemoveConsumptionUseCase.self) { resolver in
                RemoveConsumptionUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(ObservePendingDraftsUseCase.self) { resolver in
                ObservePendingDraftsUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(AcceptDraftUseCase.self) { resolver in
                AcceptDraftUseCaseImpl(
                    repository: resolver.required(PlanningRepository.self),
                    syncScheduler: resolver.required(SyncScheduling.self)
                )
            }
            container.register(DiscardDraftUseCase.self) { resolver in
                DiscardDraftUseCaseImpl(
                    repository: resolver.required(PlanningRepository.self),
                    syncScheduler: resolver.required(SyncScheduling.self)
                )
            }
        }
    }
}

// MARK: - ViewModels

extension Assembly {
    static func makePlanningViewModel(container: DependencyContainer = .shared) -> PlanningViewModel {
        PlanningViewModel(
            useCases: PlanningViewModel.UseCases(
                observeWeekPlan: container.required(ObserveWeekPlanUseCase.self),
                observePendingDrafts: container.required(ObservePendingDraftsUseCase.self),
                observeHousehold: container.required(ObserveHouseholdUseCase.self),
                updatePlannedMeal: container.required(UpdatePlannedMealUseCase.self),
                removePlannedMeal: container.required(RemovePlannedMealUseCase.self),
                discardDraft: container.required(DiscardDraftUseCase.self)
            )
        )
    }

    static func makePlanMealViewModel(
        request: PlanMealRequest,
        container: DependencyContainer = .shared
    ) -> PlanMealViewModel {
        PlanMealViewModel(
            request: request,
            planMeal: container.required(PlanMealUseCase.self),
            updatePlannedMeal: container.required(UpdatePlannedMealUseCase.self),
            removePlannedMeal: container.required(RemovePlannedMealUseCase.self),
            observeRecipeCatalog: container.required(ObserveRecipeCatalogUseCase.self),
            observeHousehold: container.required(ObserveHouseholdUseCase.self)
        )
    }

    static func makeDraftReviewViewModel(
        draftID: UUID,
        container: DependencyContainer = .shared
    ) -> DraftReviewViewModel {
        DraftReviewViewModel(
            draftID: draftID,
            observePendingDrafts: container.required(ObservePendingDraftsUseCase.self),
            acceptDraft: container.required(AcceptDraftUseCase.self),
            discardDraft: container.required(DiscardDraftUseCase.self)
        )
    }
}
