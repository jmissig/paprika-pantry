import Foundation

public struct RemoteRecipeStub: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let hash: String?
    public let isDeleted: Bool

    public init(uid: String, name: String, hash: String?, isDeleted: Bool = false) {
        self.uid = uid
        self.name = name
        self.hash = hash
        self.isDeleted = isDeleted
    }
}

public struct RemoteRecipeCategory: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let isDeleted: Bool

    public init(uid: String, name: String, isDeleted: Bool = false) {
        self.uid = uid
        self.name = name
        self.isDeleted = isDeleted
    }
}

public struct RemoteRecipe: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categoryReferences: [String]
    public let sourceName: String?
    public let ingredients: String?
    public let directions: String?
    public let notes: String?
    public let starRating: Int?
    public let isFavorite: Bool
    public let prepTime: String?
    public let cookTime: String?
    public let totalTime: String?
    public let servings: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let remoteHash: String?
    public let rawJSON: String

    public init(
        uid: String,
        name: String,
        categoryReferences: [String],
        sourceName: String?,
        ingredients: String?,
        directions: String?,
        notes: String?,
        starRating: Int?,
        isFavorite: Bool,
        prepTime: String?,
        cookTime: String?,
        totalTime: String?,
        servings: String?,
        createdAt: String?,
        updatedAt: String?,
        remoteHash: String?,
        rawJSON: String
    ) {
        self.uid = uid
        self.name = name
        self.categoryReferences = categoryReferences
        self.sourceName = sourceName
        self.ingredients = ingredients
        self.directions = directions
        self.notes = notes
        self.starRating = starRating
        self.isFavorite = isFavorite
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteHash = remoteHash
        self.rawJSON = rawJSON
    }
}

public protocol PaprikaRemoteClient: Sendable {
    func listRecipeStubs() async throws -> [RemoteRecipeStub]
    func listRecipeCategories() async throws -> [RemoteRecipeCategory]
    func fetchRecipe(uid: String) async throws -> RemoteRecipe
}
