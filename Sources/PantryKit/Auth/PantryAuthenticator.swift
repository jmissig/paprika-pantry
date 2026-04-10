import Foundation

public enum AuthStrategy: String, Codable, Equatable, Sendable {
    case simpleAccount = "simple-account"
    case licensedClient = "licensed-client"
}

public protocol PantryAuthenticator: Sendable {
    var strategy: AuthStrategy { get }
    func login(emailAddress: String, password: String) async throws -> PantrySession
}
