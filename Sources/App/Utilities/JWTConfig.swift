import Vapor
import JWT

enum IssuerType: String {
    case password
    case facebook
}

public struct JWTConfig: Service {
    let secret: String
    let accessTokenValidDuration: TimeInterval
    let refreshTokenValidDuration: TimeInterval
    
    public init(secret: String, accessTokenValidDuration: TimeInterval, refreshTokenValidDuration: TimeInterval) {
        self.secret = secret
        self.accessTokenValidDuration = accessTokenValidDuration
        self.refreshTokenValidDuration = refreshTokenValidDuration
    }
    
    func accessTokenForUserID(_ userID: UUID, issuerType: IssuerType) throws -> (token: String, expiresIn: TimeInterval) {
        let signer = JWTSigner.hs256(key: Data(secret.utf8))
        let expirationDate = Date(timeIntervalSinceNow: accessTokenValidDuration)
        let exp = ExpirationClaim(value: expirationDate)
        let sub = SubjectClaim(value: userID.uuidString)
        let iss = IssuerClaim(value: issuerType.rawValue)
        let jwt = JWT(payload: JWTAuthorizationPayload(exp: exp, sub: sub, iss: iss))
        let data = try signer.sign(jwt)
        guard let token = String(data: data, encoding: .utf8) else {
            throw Abort(.internalServerError)
        }
        return (token, accessTokenValidDuration)
    }
}
