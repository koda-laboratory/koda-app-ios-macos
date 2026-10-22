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

            container.register(ObserveTodayMealsUseCase.self) { resolver in
                ObserveTodayMealsUseCaseImpl(planningRepository: resolver.required(PlanningRepository.self))
            }
            container.register(ObserveWeekPlanUseCase.self) { resolver in
                ObserveWeekPlanUseCaseImpl(repository: resolver.required(PlanningRepository.self))
            }
            container.register(PlanMealUseCase.self) { resolver in
                PlanMealUseCaseImpl(repository: resolver.required(PlanningRepository.self))
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
