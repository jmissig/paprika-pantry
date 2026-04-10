import Foundation

public struct PantrySession: Codable, Equatable, Sendable {
    public let authStrategy: AuthStrategy
    public let emailAddress: String
    public let token: String
    public let createdAt: Date

    public init(
        emailAddress: String,
        token: String,
        createdAt: Date,
        authStrategy: AuthStrategy = .simpleAccount
    ) {
        self.authStrategy = authStrategy
        self.emailAddress = emailAddress
        self.token = token
        self.createdAt = createdAt
    }
}
