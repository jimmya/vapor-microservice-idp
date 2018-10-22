import Vapor
import FluentPostgreSQL
import S3

struct FileUpload: Content {
    
    let file: Core.File
}

struct AuthController: RouteCollection {
    
    private let repository: RefreshTokenRepository
    
    init(repository: RefreshTokenRepository) {
        self.repository = repository
    }
    
    func boot(router: Router) throws {
        let authRouter = router.grouped("auth")
        
        authRouter.post(GetTokenRequest.self, at: "token", use: getToken)
        authRouter.post(FileUpload.self, at: "upload", use: uploadFile)
    }
}

private extension AuthController {
    
    func uploadFile(_ req: Request, uploadRequest: FileUpload) throws -> Future<HTTPStatus> {
        let s3 = try req.makeS3Client()
        let fileName = UUID().uuidString + ".jpg"
        let mimeType = uploadRequest.file.contentType?.description ?? MediaType.plainText.description
        let file = File.Upload(data: uploadRequest.file.data, destination: fileName, access: .publicRead, mime: mimeType) // Note: only add `access: .publicRead` if you want the file to be available for anyone to download
        return try s3.put(file: file, on: req).map { response in
            // Either do something with response, e.g. store file url in db etc.
            
            // Generate url to store in db
            let signer = try req.make(S3Signer.self)
            let url = signer.config.region.hostUrlString(bucket: response.bucket) + response.path
            return .created
        }
    }
    
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
            return refreshTokenRepository.store(token: refreshTokenEntity)
            }.map { refreshToken in
                let accessToken = try jwtConfig.accessTokenForUserID(refreshToken.userID, issuerType: .password)
                return GetTokenResponse(accessToken: accessToken.token, refreshToken: refreshToken.token, expiresIn: accessToken.expiresIn)
        }
    }
    
    func getTokenByRefresh(_ req: Request, getTokenRequest: GetTokenRequest) throws -> Future<GetTokenResponse> {
        guard let refreshToken = getTokenRequest.refreshToken else { throw Abort(.badRequest) }
        let repository = try req.make(RefreshTokenRepository.self)
        let jwtConfig = try req.make(JWTConfig.self)
        return repository.find(token: refreshToken).flatMap { (token) -> Future<RefreshToken> in
            guard let token = token else { throw Abort(.unauthorized) }
            guard token.expires.timeIntervalSinceNow > 0 else { throw Abort(.unauthorized) }
            return repository.delete(token: token).map { token }
            }.flatMap(to: RefreshToken.self) { token in
                let refreshToken = UUID().uuidString
                let expires = Date(timeIntervalSinceNow: jwtConfig.refreshTokenValidDuration)
                let refreshTokenEntity = RefreshToken(userID: token.userID, token: refreshToken, expires: expires)
                return repository.store(token: refreshTokenEntity)
            }.map { refreshToken in
                let accessToken = try jwtConfig.accessTokenForUserID(refreshToken.userID, issuerType: .password)
                return GetTokenResponse(accessToken: accessToken.token, refreshToken: refreshToken.token, expiresIn: accessToken.expiresIn)
        }
    }
}
