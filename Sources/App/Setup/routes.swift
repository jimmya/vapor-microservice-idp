import Vapor

public func routes(_ router: Router) throws {
    
    let authController = AuthController()
    try router.register(collection: authController)
}
