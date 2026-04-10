import Foundation

public struct PantryConfig: Codable, Equatable, Sendable {
    public let authStrategy: AuthStrategy
    public let lastEmailAddress: String?
    public let updatedAt: Date

    public init(authStrategy: AuthStrategy, lastEmailAddress: String?, updatedAt: Date) {
        self.authStrategy = authStrategy
        self.lastEmailAddress = lastEmailAddress
        self.updatedAt = updatedAt
    }
}
