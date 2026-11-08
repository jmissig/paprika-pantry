import Foundation

public struct RecipeCollectionContext: Codable, Equatable, Sendable {
    public let uid: String?
    public let name: String?
    public let resolution: String
}

public struct SourceCollection: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let isDefault: Bool
}
