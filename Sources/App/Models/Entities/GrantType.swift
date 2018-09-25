import Vapor

enum GrantType: String, Content {
    case password
    case refreshToken = "refresh_token"
}
