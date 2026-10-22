import Swinject

extension Assembly {
    final class Core: Swinject.Assembly {
        func assemble(container: Container) {
            registerInfrastructure(in: container)
            registerHTTP(in: container)
            registerSession(in: container)
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
                    sessionRecovery: resolver.required(HTTPSessionRecovery.self)
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
    }
}
