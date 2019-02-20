import Vapor
import FluentPostgreSQL
import ServiceExt

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    
    Environment.dotenv()
    
    services.register { container -> NIOServerConfig in
        switch container.environment {
        case .production: return .default()
        default: return .default(port: 8081)
        }
    }
    
    try services.register(FluentPostgreSQLProvider())
    
    services.register(Router.self) { container -> EngineRouter in
        let router = EngineRouter.default()
        try routes(router, container)
        return router
    }
    
    /// Register middlewares
    var middlewaresConfig = MiddlewareConfig()
    try middlewares(config: &middlewaresConfig)
    services.register(middlewaresConfig)
    
    var databasesConfig = DatabasesConfig()
    try databases(config: &databasesConfig)
    services.register(databasesConfig)

    services.register { container -> MigrationConfig in
        var migrationConfig = MigrationConfig()
        try migrate(migrations: &migrationConfig)
        return migrationConfig
    }
    
    setupRepositories(services: &services, config: &config)
    
    try setupClients(services: &services, config: &config)
    
    guard let jwtSecret: String = Environment.get("JWT_SECRET"),
        let accessTokenValidDurationString: String = Environment.get("ACCESS_TOKEN_VALID_DURATION"),
        let accessTokenValidDuration = TimeInterval(accessTokenValidDurationString),
        let refreshTokenValidDurationString: String = Environment.get("REFRESH_TOKEN_VALID_DURATION"),
        let refreshTokenValidDuration = TimeInterval(refreshTokenValidDurationString)else {
        throw Abort(.internalServerError)
    }
    let jwtConfig = JWTConfig(secret: jwtSecret,
                              accessTokenValidDuration: accessTokenValidDuration,
                              refreshTokenValidDuration: refreshTokenValidDuration)
    services.register(jwtConfig)
}
