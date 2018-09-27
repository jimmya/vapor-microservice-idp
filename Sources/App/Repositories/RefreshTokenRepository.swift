import Vapor
import FluentPostgreSQL

protocol RefreshTokenRepository: ServiceType {
    func find(token: String) -> Future<RefreshToken?>
    func store(token: RefreshToken) -> Future<RefreshToken>
    func delete(token: RefreshToken) -> Future<Void>
}

final class PostgreRefreshTokenRepository: RefreshTokenRepository {
    
    let database: PostgreSQLDatabase.ConnectionPool
    
    init(_ database: PostgreSQLDatabase.ConnectionPool) {
        self.database = database
    }
    
    func find(token: String) -> EventLoopFuture<RefreshToken?> {
        return database.withConnection { connection in
            return RefreshToken.query(on: connection).filter(\.token == token).first()
        }
    }
    
    func store(token: RefreshToken) -> EventLoopFuture<RefreshToken> {
        return database.withConnection { connection in
            return token.save(on: connection)
        }
    }
    
    func delete(token: RefreshToken) -> EventLoopFuture<Void> {
        return database.withConnection { connection in
            return token.delete(on: connection)
        }
    }
}

//MARK: - ServiceType conformance
extension PostgreRefreshTokenRepository {
    static let serviceSupports: [Any.Type] = [RefreshTokenRepository.self]
    
    static func makeService(for worker: Container) throws -> Self {
        return .init(try worker.connectionPool(to: .psql))
    }
}

extension Database {
    public typealias ConnectionPool = DatabaseConnectionPool<ConfiguredDatabase<Self>>
}
