import Foundation

public struct PantryConfig: Codable, Equatable, Sendable {
    public let source: PantrySourceConfiguration?
    public let updatedAt: Date

    public init(source: PantrySourceConfiguration?, updatedAt: Date) {
        self.source = source
        self.updatedAt = updatedAt
    }
}
