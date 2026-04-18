import Foundation

public struct PantryConfig: Codable, Equatable, Sendable {
    public let source: PaprikaSourceConfiguration?
    public let updatedAt: Date

    public init(source: PaprikaSourceConfiguration?, updatedAt: Date) {
        self.source = source
        self.updatedAt = updatedAt
    }
}
