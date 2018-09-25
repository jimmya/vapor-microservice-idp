import Vapor

struct LoginRequest: Content {
    
    let email: String
    let password: String
    
    init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

extension LoginRequest: Equatable { }
