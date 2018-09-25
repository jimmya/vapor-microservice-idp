import Vapor

struct AuthController: RouteCollection {
    
    func boot(router: Router) throws {
        let authRouter = router.grouped("auth")
        
        authRouter.post(GetTokenRequest.self, at: "token", use: getToken)
    }
}

private extension AuthController {
    
    func getToken(_ req: Request, getTokenRequest: GetTokenRequest) throws -> Future<GetTokenResponse> {
        switch getTokenRequest.grantType {
        case .password:
            return try getTokenByPassword(req, getTokenRequest: getTokenRequest)
        case .refreshToken:
            return try getTokenByRefresh(req, getTokenRequest: getTokenRequest)
        }
    }
    
    func getTokenByPassword(_ req: Request, getTokenRequest: GetTokenRequest) throws -> Future<GetTokenResponse> {
        guard let email = getTokenRequest.username, let password = getTokenRequest.password else {
            throw Abort(.badRequest)
        }
        let userClient = try req.make(UserClient.self)
        let refreshTokenRepository = try req.make(RefreshTokenRepository.self)
        let jwtConfig = try req.make(JWTConfig.self)
        return try userClient.findUser(email: email, password: password, on: req).flatMap(to: RefreshToken.self) { user in
            let refreshToken = UUID().uuidString
            let expires = Date(timeIntervalSinceNow: jwtConfig.refreshTokenValidDuration)
            let refreshTokenEntity = RefreshToken(userID: user.id, token: refreshToken, expires: expires)
            return refreshTokenRepository.store(token: refreshTokenEntity, on: req)
            }.map { refreshToken in
                let accessToken = try jwtConfig.accessTokenForUserID(refreshToken.userID, issuerType: .password)
                return GetTokenResponse(accessToken: accessToken.token, refreshToken: refreshToken.token, expiresIn: accessToken.expiresIn)
        }
    }
    
    func getTokenByRefresh(_ req: Request, getTokenRequest: GetTokenRequest) throws -> Future<GetTokenResponse> {
        guard let refreshToken = getTokenRequest.refreshToken else { throw Abort(.badRequest) }
        let repository = try req.make(RefreshTokenRepository.self)
        let jwtConfig = try req.make(JWTConfig.self)
        return repository.find(token: refreshToken, on: req).flatMap(to: GetTokenResponse.self) { token in
            guard let token = token else { throw Abort(.unauthorized) }
            guard token.expires.timeIntervalSinceNow > 0 else { throw Abort(.unauthorized) }
            return repository.delete(token: token, on: req).flatMap(to: RefreshToken.self) {
                let refreshToken = UUID().uuidString
                let expires = Date(timeIntervalSinceNow: jwtConfig.refreshTokenValidDuration)
                let refreshTokenEntity = RefreshToken(userID: token.userID, token: refreshToken, expires: expires)
                return repository.store(token: refreshTokenEntity, on: req)
                }.map { refreshToken in
                    let accessToken = try jwtConfig.accessTokenForUserID(refreshToken.userID, issuerType: .password)
                    return GetTokenResponse(accessToken: accessToken.token, refreshToken: refreshToken.token, expiresIn: accessToken.expiresIn)
            }
        }
    }
}
