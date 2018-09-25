import Vapor
import FluentPostgreSQL

protocol RefreshTokenRepository: Service {
    func find(token: String, on connectable: DatabaseConnectable) -> Future<RefreshToken?>
    func store(token: RefreshToken, on connectable: DatabaseConnectable) -> Future<RefreshToken>
    func delete(token: RefreshToken, on connectable: DatabaseConnectable) -> Future<Void>
}

final class PostgreRefreshTokenRepository: RefreshTokenRepository {
    
    func find(token: String, on connectable: DatabaseConnectable) -> EventLoopFuture<RefreshToken?> {
        return RefreshToken.query(on: connectable).filter(\.token == token).first()
    }
    
    func store(token: RefreshToken, on connectable: DatabaseConnectable) -> EventLoopFuture<RefreshToken> {
        return token.save(on: connectable)
    }
    
    func delete(token: RefreshToken, on connectable: DatabaseConnectable) -> EventLoopFuture<Void> {
        return token.delete(on: connectable)
    }
}
