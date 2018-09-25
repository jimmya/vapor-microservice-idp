import XCTest

@testable import AppTests

XCTMain([
    testCase(AuthControllerTests.allTests),
    testCase(UserClientTests.allTests),
    ])
