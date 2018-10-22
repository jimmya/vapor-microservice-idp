import Vapor

public func routes(_ router: Router, _ container: Container) throws {

    let refreshTokenRepository = try container.make(RefreshTokenRepository.self)
    let authController = AuthController(repository: refreshTokenRepository)
    try router.register(collection: authController)
}
