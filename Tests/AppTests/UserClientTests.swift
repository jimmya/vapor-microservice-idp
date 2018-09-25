import Vapor
@testable import App
import XCTest

final class UserClientTests: XCTestCase {
    
    var container: BasicContainer!
    var mockClient: MockClient!
    
    override func setUp() {
        super.setUp()
        
        let config = Config()
        var services = Services()
        services.register(ContentConfig.self)
        services.register(ContentCoders.self)
        container = BasicContainer(
            config: config,
            environment: .testing,
            services: services,
            on: EmbeddedEventLoop()
        )
        mockClient = MockClient(container: container)
        container.services.register(mockClient, as: Client.self)
    }
    
    func testFindUserShouldSendRequest() throws {
        // Given
        let host = "http://google.com"
        let email = "arts.jimmy@gmail.com"
        let password = "Wachtwoord123!?"
        let expectedLoginRequest = LoginRequest(email: email, password: password)
        let client = RemoteUserClient(host: host)
        let expectedURL = URL(string: host + "/users/login")!
        mockClient.mockSendResponse = container.eventLoop.newSucceededFuture(result: Response(http: HTTPResponse(status: .ok), using: container))
        
        // When
        _ = try client.findUser(email: email, password: password, on: container)
        
        // Then
        let requestBody = try mockClient.invokedSendParameters?.content.decode(LoginRequest.self).wait()
        XCTAssertTrue(mockClient.invokedSend)
        XCTAssertEqual(requestBody!, expectedLoginRequest)
        XCTAssertEqual(mockClient.invokedSendParameters?.http.method, .POST)
        XCTAssertEqual(mockClient.invokedSendParameters?.http.url, expectedURL)
    }
    
    func testFindUserShouldReturnUser() throws {
        // Given
        let host = "http://google.com"
        let email = "arts.jimmy@gmail.com"
        let password = "Wachtwoord123!?"
        let getUserResponse = GetUserResponse(id: UUID(), username: "Jimmy", email: "arts.jimmy@gmail.com")
        let client = RemoteUserClient(host: host)
        mockClient.mockSendResponse = container.eventLoop.newSucceededFuture(result: Response(http: HTTPResponse(status: .ok, headers: ["Content-Type": "application/json"], body: try JSONEncoder().encode(getUserResponse)), using: container))
        
        // When
        let response = try client.findUser(email: email, password: password, on: container).wait()
        
        // Then
        XCTAssertEqual(response, getUserResponse)
    }
    
    func testFindUserErrorShouldThrowError() throws {
        // Given
        let host = "http://google.com"
        let email = "arts.jimmy@gmail.com"
        let password = "Wachtwoord123!?"
        let client = RemoteUserClient(host: host)
        mockClient.mockSendResponse = container.eventLoop.newSucceededFuture(result: Response(http: HTTPResponse(status: .ok), using: container))
        
        // When
        XCTAssertThrowsError(try client.findUser(email: email, password: password, on: container).wait())
    }
    
    final class MockClient: Client, Service {
        
        var container: Container
        
        init(container: Container) {
            self.container = container
        }
        
        var invokedSend = false
        var invokedSendCount = 0
        var invokedSendParameters: Request?
        var mockSendResponse: EventLoopFuture<Response>!
        func send(_ req: Request) -> EventLoopFuture<Response> {
            invokedSend = true
            invokedSendCount += 1
            invokedSendParameters = req
            return mockSendResponse
        }
    }
}
