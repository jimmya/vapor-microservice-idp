import FluentPostgreSQL
import Vapor

struct RefreshToken {
    
    var id: UUID?
    var userID: UUID
    var token: String
    var expires: Date

    init(id: UUID? = nil, userID: UUID, token: String, expires: Date) {
        self.id = id
        self.userID = userID
        self.token = token
        self.expires = expires
    }
}

extension RefreshToken: PostgreSQLUUIDModel { }
extension RefreshToken: Migration { }
extension RefreshToken: Equatable { }
