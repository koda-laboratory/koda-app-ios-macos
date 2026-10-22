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
        }
    }
}
