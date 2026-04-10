import Foundation

public struct PantrySession: Codable, Equatable, Sendable {
    public let emailAddress: String
    public let token: String
    public let createdAt: Date

    public init(emailAddress: String, token: String, createdAt: Date) {
        self.emailAddress = emailAddress
        self.token = token
        self.createdAt = createdAt
    }
}
