import Vapor

protocol UserClient: Service {
    func findUser(email: String, password: String, on container: Container) throws -> Future<GetUserResponse>
}

final class RemoteUserClient: UserClient {
    
    private let host: String
    
    init(host: String) {
        self.host = host
    }
    
    func findUser(email: String, password: String, on container: Container) throws -> EventLoopFuture<GetUserResponse> {
        let url = host + "/users/login"
        let request = LoginRequest(email: email, password: password)
        return try container.client().post(url) { req in
            try req.content.encode(request)
            }.flatMap { response in
                return try response.content.decode(GetUserResponse.self)
        }
    }
}
