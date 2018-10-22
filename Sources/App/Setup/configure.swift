import Vapor
import FluentPostgreSQL
import S3

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    
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
    
    guard let jwtSecret = Environment.get("JWT_SECRET"),
        let accessTokenValidDurationString = Environment.get("ACCESS_TOKEN_VALID_DURATION"),
        let accessTokenValidDuration = TimeInterval(accessTokenValidDurationString),
        let refreshTokenValidDurationString = Environment.get("REFRESH_TOKEN_VALID_DURATION"),
        let refreshTokenValidDuration = TimeInterval(refreshTokenValidDurationString)else {
        throw Abort(.internalServerError)
    }
    let jwtConfig = JWTConfig(secret: jwtSecret,
                              accessTokenValidDuration: accessTokenValidDuration,
                              refreshTokenValidDuration: refreshTokenValidDuration)
    services.register(jwtConfig)
    
    guard let accessKey = Environment.get("AWS_ACCESS_KEY"),
        let secretKey = Environment.get("AWS_SECRET_KEY"),
        let bucket = Environment.get("AWS_DEFAULT_BUCKET") else {
        throw Abort(.internalServerError, reason: "AWS credentials not configured")
    }
    try services.register(s3: S3Signer.Config(accessKey: accessKey, secretKey: secretKey, region: .euWest1), defaultBucket: bucket)
}
