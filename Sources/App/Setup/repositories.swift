import Vapor

public func setupRepositories(services: inout Services, config: inout Config) {
    services.register(RefreshTokenRepository.self) { _ -> PostgreRefreshTokenRepository in
        return PostgreRefreshTokenRepository()
    }
}
