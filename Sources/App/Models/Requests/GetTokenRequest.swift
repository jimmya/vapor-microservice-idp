import Vapor

struct GetTokenRequest: Content {
    
    let grantType: GrantType
    let username: String?
    let password: String?
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case username
        case password
        case refreshToken = "refresh_token"
    }
}
