import Vapor

public func setupClients(services: inout Services, config: inout Config) throws {
    guard let usersHost: String = Environment.get("USERS_HOST") else {
        throw Abort(.internalServerError, reason: "No user service host provided")
    }
    services.register(UserClient.self) { _ -> RemoteUserClient in
        return RemoteUserClient(host: usersHost)
    }
}
