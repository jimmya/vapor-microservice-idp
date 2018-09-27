import Vapor
@testable import App
import XCTest

final class AuthControllerTests: XCTestCase {
    
    var app: Application!
    var mockUserClient: MockUserClient!
    var mockRefreshTokenRepository: MockRefreshTokenRepository!
    
    override func setUp() {
        super.setUp()
        mockUserClient = MockUserClient()
        mockRefreshTokenRepository = MockRefreshTokenRepository()
        var config = Config.default()
        var services = Services.default()
        services.register(UserClient.self) { _ -> MockUserClient in
            return self.mockUserClient
        }
        config.prefer(MockUserClient.self, for: UserClient.self)
        
        services.register(RefreshTokenRepository.self) { _ -> MockRefreshTokenRepository in
            return self.mockRefreshTokenRepository
        }
        config.prefer(MockRefreshTokenRepository.self, for: RefreshTokenRepository.self)
        
        app = try! Application.testable(config: config, services: services)
    }
    
    // MARK: Password auth
    
    func testPasswordAuthShouldReturnGetTokenResponse() throws {
        // Given
        let userUUID = UUID()
        let tokenUUID = UUID()
        let expires = Date()
        let tokenString = "TokenString"
        let getUserResponse = GetUserResponse(id: userUUID, username: "Jimmy", email: "arts.jimmy@gmail.com")
        mockUserClient.mockFindUserResponse = app.eventLoop.newSucceededFuture(result: getUserResponse)
        let storeTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: tokenString, expires: expires)
        mockRefreshTokenRepository.mockStoreResponse = app.eventLoop.newSucceededFuture(result: storeTokenResponse)
        let request = GetTokenRequest(grantType: .password, username: "arts.jimmy@gmail.com", password: "Wachtwoord123!?", refreshToken: nil)
        
        // When
        let response = try app.getResponse(to: "/auth/token", method: .POST, headers: [:], data: request, decodeTo: GetTokenResponse.self)

        // Then
        XCTAssertEqual(response.refreshToken, tokenString)
        XCTAssertEqual(response.expiresIn, 3600)
    }
    
    func testPasswordAuthWithoutUsernameShouldReturnError() throws {
        // Given
        let request = GetTokenRequest(grantType: .password, username: nil, password: "Wachtwoord123!?", refreshToken: nil)
        
        // When
        let response = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertEqual(response.http.status, .badRequest)
    }
    
    func testPasswordAuthWithoutPasswordShouldReturnError() throws {
        // Given
        let request = GetTokenRequest(grantType: .password, username: "arts.jimmy@gmail.com", password: nil, refreshToken: nil)
        
        // When
        let response = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertEqual(response.http.status, .badRequest)
    }
    
    func testPasswordAuthShouldStoreRefreshTokenInRepository() throws {
        // Given
        let userUUID = UUID()
        let tokenUUID = UUID()
        let expires = Date()
        let getUserResponse = GetUserResponse(id: userUUID, username: "Jimmy", email: "arts.jimmy@gmail.com")
        mockUserClient.mockFindUserResponse = app.eventLoop.newSucceededFuture(result: getUserResponse)
        let storeTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: "TokenString", expires: expires)
        mockRefreshTokenRepository.mockStoreResponse = app.eventLoop.newSucceededFuture(result: storeTokenResponse)
        let request = GetTokenRequest(grantType: .password, username: "arts.jimmy@gmail.com", password: "Wachtwoord123!?", refreshToken: nil)
        
        // When
        _ = try app.getResponse(to: "/auth/token", method: .POST, headers: [:], data: request, decodeTo: GetTokenResponse.self)
        
        // Then
        XCTAssertTrue(mockRefreshTokenRepository.invokedStore)
    }
    
    func testPasswordAuthShouldRetrieveUserFromUserService() throws {
        // Given
        let email = "arts.jimmy@gmail.com"
        let password = "Wachtwoord123!?"
        let request = GetTokenRequest(grantType: .password, username: email, password: password, refreshToken: nil)
        mockUserClient.mockFindUserError = Abort(.badRequest)
        
        // When
        _ = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertTrue(mockUserClient.invokedFindUser)
        XCTAssertEqual(mockUserClient.invokedFindUserParameters?.email, email)
        XCTAssertEqual(mockUserClient.invokedFindUserParameters?.password, password)
    }
    
    func testPasswordAuthRetrieveUserErrorShouldReturnError() throws {
        // Given
        let status: HTTPStatus = .badRequest
        mockUserClient.mockFindUserError = Abort(status)
        let request = GetTokenRequest(grantType: .password, username: "arts.jimmy@gmail.com", password: "Wachtwoord123!?", refreshToken: nil)
        
        // When
        let response = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertEqual(response.http.status, status)
    }
    
    // MARK: Refresh token auth
    
    func testRefreshTokenAuthShouldReturnGetTokenResponse() throws {
        // Given
        let userUUID = UUID()
        let tokenUUID = UUID()
        let expires = Date()
        let tokenString = "TokenString"
        let getTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: "Token", expires: Date(timeIntervalSinceNow: 60))
        mockRefreshTokenRepository.mockFindResponse = app.eventLoop.newSucceededFuture(result: getTokenResponse)
        let storeTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: tokenString, expires: expires)
        mockRefreshTokenRepository.mockStoreResponse = app.eventLoop.newSucceededFuture(result: storeTokenResponse)
        mockRefreshTokenRepository.mockDeleteResponse = app.eventLoop.newSucceededFuture(result: ())
        let request = GetTokenRequest(grantType: .refreshToken, username: nil, password: nil, refreshToken: "Token")
        
        // When
        let response = try app.getResponse(to: "/auth/token", method: .POST, headers: [:], data: request, decodeTo: GetTokenResponse.self)
        
        // Then
        XCTAssertEqual(response.refreshToken, tokenString)
        XCTAssertEqual(response.expiresIn, 3600)
    }
    
    func testRefreshTokenWithoutTokenShouldReturnError() throws {
        // Given
        let request = GetTokenRequest(grantType: .refreshToken, username: nil, password: nil, refreshToken: nil)
        
        // When
        let response = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertEqual(response.http.status, .badRequest)
    }
    
    func testRefreshTokenFindTokenNilShouldReturnError() throws {
        // Given
        mockRefreshTokenRepository.mockFindResponse = app.eventLoop.newSucceededFuture(result: nil)
        let request = GetTokenRequest(grantType: .refreshToken, username: nil, password: nil, refreshToken: "Token")
        
        // When
        let response = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertEqual(response.http.status, .unauthorized)
    }
    
    func testRefreshTokenExpiredShouldReturnError() throws {
        // Given
        let userUUID = UUID()
        let tokenUUID = UUID()
        let getTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: "Token", expires: Date(timeIntervalSince1970: 0))
        mockRefreshTokenRepository.mockFindResponse = app.eventLoop.newSucceededFuture(result: getTokenResponse)
        let request = GetTokenRequest(grantType: .refreshToken, username: nil, password: nil, refreshToken: "Token")
        
        // When
        let response = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertEqual(response.http.status, .unauthorized)
    }
    
    func testRefreshTokenShouldDeleteProvidedToken() throws {
        // Given
        let userUUID = UUID()
        let tokenUUID = UUID()
        let expires = Date()
        let tokenString = "TokenString"
        let getTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: "Token", expires: Date(timeIntervalSinceNow: 60))
        mockRefreshTokenRepository.mockFindResponse = app.eventLoop.newSucceededFuture(result: getTokenResponse)
        mockRefreshTokenRepository.mockDeleteResponse = app.eventLoop.newSucceededFuture(result: ())
        let storeTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: tokenString, expires: expires)
        mockRefreshTokenRepository.mockStoreResponse = app.eventLoop.newSucceededFuture(result: storeTokenResponse)
        let request = GetTokenRequest(grantType: .refreshToken, username: nil, password: nil, refreshToken: "Token")
        
        // When
        _ = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertTrue(mockRefreshTokenRepository.invokedDelete)
        XCTAssertEqual(mockRefreshTokenRepository.invokedDeleteParameters, getTokenResponse)
    }
    
    func testRefreshTokenShouldStoreNewToken() throws {
        // Given
        let userUUID = UUID()
        let tokenUUID = UUID()
        let expires = Date()
        let tokenString = "TokenString"
        let getTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: "Token", expires: Date(timeIntervalSinceNow: 60))
        mockRefreshTokenRepository.mockFindResponse = app.eventLoop.newSucceededFuture(result: getTokenResponse)
        let storeTokenResponse = RefreshToken(id: tokenUUID, userID: userUUID, token: tokenString, expires: expires)
        mockRefreshTokenRepository.mockStoreResponse = app.eventLoop.newSucceededFuture(result: storeTokenResponse)
        mockRefreshTokenRepository.mockDeleteResponse = app.eventLoop.newSucceededFuture(result: ())
        let request = GetTokenRequest(grantType: .refreshToken, username: nil, password: nil, refreshToken: "Token")
        
        // When
        _ = try app.sendRequest(to: "/auth/token", method: .POST, headers: [:], body: request)
        
        // Then
        XCTAssertTrue(mockRefreshTokenRepository.invokedStore)
    }
    
    static let allTests = [
        ("testPasswordAuthShouldReturnGetTokenResponse", testPasswordAuthShouldReturnGetTokenResponse),
        ("testPasswordAuthWithoutUsernameShouldReturnError", testPasswordAuthWithoutUsernameShouldReturnError),
        ("testPasswordAuthWithoutPasswordShouldReturnError", testPasswordAuthWithoutPasswordShouldReturnError),
        ("testPasswordAuthShouldStoreRefreshTokenInRepository", testPasswordAuthShouldStoreRefreshTokenInRepository),
        ("testPasswordAuthShouldRetrieveUserFromUserService", testPasswordAuthShouldRetrieveUserFromUserService),
        ("testPasswordAuthRetrieveUserErrorShouldReturnError", testPasswordAuthRetrieveUserErrorShouldReturnError),
        ("testRefreshTokenAuthShouldReturnGetTokenResponse", testRefreshTokenAuthShouldReturnGetTokenResponse),
        ("testRefreshTokenWithoutTokenShouldReturnError", testRefreshTokenWithoutTokenShouldReturnError),
        ("testRefreshTokenFindTokenNilShouldReturnError", testRefreshTokenFindTokenNilShouldReturnError),
        ("testRefreshTokenExpiredShouldReturnError", testRefreshTokenExpiredShouldReturnError),
        ("testRefreshTokenShouldDeleteProvidedToken", testRefreshTokenShouldDeleteProvidedToken),
        ("testRefreshTokenShouldStoreNewToken", testRefreshTokenShouldStoreNewToken)
    ]
    
    final class MockUserClient: UserClient {
        
        var invokedFindUser = false
        var invokedFindUserCount = 0
        var invokedFindUserParameters: (email: String, password: String, container: Container)?
        var mockFindUserResponse: EventLoopFuture<GetUserResponse>!
        var mockFindUserError: Error?
        func findUser(email: String, password: String, on container: Container) throws -> EventLoopFuture<GetUserResponse> {
            invokedFindUser = true
            invokedFindUserCount += 1
            invokedFindUserParameters = (email, password, container)
            if let mockError = mockFindUserError {
                throw mockError
            }
            return mockFindUserResponse
        }
    }
    
    final class MockRefreshTokenRepository: RefreshTokenRepository {
        
        static func makeService(for worker: Container) throws -> Self {
            return .init()
        }
        
        var invokedFind = false
        var invokedFindCount = 0
        var invokedFindParameters: String?
        var mockFindResponse: EventLoopFuture<RefreshToken?>!
        func find(token: String) -> EventLoopFuture<RefreshToken?> {
            invokedFind = true
            invokedFindCount += 1
            invokedFindParameters = token
            return mockFindResponse
        }
        
        var invokedStore = false
        var invokedStoreCount = 0
        var invokedStoreParameters: RefreshToken?
        var mockStoreResponse: EventLoopFuture<RefreshToken>!
        func store(token: RefreshToken) -> EventLoopFuture<RefreshToken> {
            invokedStore = true
            invokedStoreCount += 1
            invokedStoreParameters = token
            return mockStoreResponse
        }
        
        var invokedDelete = false
        var invokedDeleteCount = 0
        var invokedDeleteParameters: RefreshToken?
        var mockDeleteResponse: EventLoopFuture<Void>!
        func delete(token: RefreshToken) -> EventLoopFuture<Void> {
            invokedDelete = true
            invokedDeleteCount += 1
            invokedDeleteParameters = token
            return mockDeleteResponse
        }
    }
}
