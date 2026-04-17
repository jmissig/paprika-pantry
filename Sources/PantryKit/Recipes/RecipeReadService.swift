import Foundation

public struct RecipeSummary: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]
    public let sourceName: String?
    public let starRating: Int?
    public let isFavorite: Bool
    public let updatedAt: String?

    public init(
        uid: String,
        name: String,
        categories: [String],
        sourceName: String?,
        starRating: Int?,
        isFavorite: Bool,
        updatedAt: String?
    ) {
        self.uid = uid
        self.name = name
        self.categories = categories
        self.sourceName = sourceName
        self.starRating = starRating
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
    }
}

public struct RecipeDetail: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]
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
        categories: [String],
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
        self.categories = categories
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

public enum RecipeReadServiceError: Error, LocalizedError, Equatable {
    case recipeNotFound(String)
    case ambiguousRecipeName(String, [String])

    public var errorDescription: String? {
        switch self {
        case .recipeNotFound(let selector):
            return "No recipe matched `\(selector)` in the configured pantry source."
        case .ambiguousRecipeName(let selector, let matchingUIDs):
            return "Recipe name `\(selector)` matched multiple source recipes. Use a UID instead: \(matchingUIDs.joined(separator: ", "))"
        }
    }
}

public struct RecipeReadService: Sendable {
    private let source: any PantrySource

    public init(source: any PantrySource) {
        self.source = source
    }

    public func listRecipes(
        filters: RecipeQueryFilters = RecipeQueryFilters(),
        sort: RecipeListSort = .name
    ) async throws -> [RecipeSummary] {
        let categoryNamesByUID = try await loadCategoryNamesByUID()
        let stubs = try await source.listRecipeStubs()
        let activeStubs = stubs.filter { !$0.isDeleted }

        var recipes = [RecipeSummary]()
        recipes.reserveCapacity(activeStubs.count)

        for stub in activeStubs {
            let recipe = try await source.fetchRecipe(uid: stub.uid)
            recipes.append(
                RecipeSummary(
                    uid: recipe.uid,
                    name: recipe.name,
                    categories: resolvedCategories(
                        recipe.categoryReferences,
                        categoryNamesByUID: categoryNamesByUID
                    ),
                    sourceName: recipe.sourceName,
                    starRating: recipe.starRating,
                    isFavorite: recipe.isFavorite,
                    updatedAt: recipe.updatedAt
                )
            )
        }

        return recipes
            .filter { filters.matches(starRating: $0.starRating, isFavorite: $0.isFavorite) }
            .sorted { Self.sortRecipes(lhs: $0, rhs: $1, by: sort) }
    }

    public func resolveRecipe(selector: String) async throws -> RecipeDetail {
        let stubs = try await source.listRecipeStubs()
        let activeStubs = stubs.filter { !$0.isDeleted }

        if activeStubs.contains(where: { $0.uid == selector }) {
            return try await fetchRecipe(uid: selector)
        }

        let nameMatches = activeStubs
            .filter { $0.name.compare(selector, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            .sorted { $0.uid < $1.uid }

        guard !nameMatches.isEmpty else {
            throw RecipeReadServiceError.recipeNotFound(selector)
        }

        guard nameMatches.count == 1 else {
            throw RecipeReadServiceError.ambiguousRecipeName(selector, nameMatches.map(\.uid))
        }

        return try await fetchRecipe(uid: nameMatches[0].uid)
    }

    private func fetchRecipe(uid: String) async throws -> RecipeDetail {
        let recipe = try await source.fetchRecipe(uid: uid)
        let categoryNamesByUID = try await loadCategoryNamesByUID()

        return RecipeDetail(
            uid: recipe.uid,
            name: recipe.name,
            categories: resolvedCategories(
                recipe.categoryReferences,
                categoryNamesByUID: categoryNamesByUID
            ),
            sourceName: recipe.sourceName,
            ingredients: recipe.ingredients,
            directions: recipe.directions,
            notes: recipe.notes,
            starRating: recipe.starRating,
            isFavorite: recipe.isFavorite,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalTime: recipe.totalTime,
            servings: recipe.servings,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            remoteHash: recipe.remoteHash,
            rawJSON: recipe.rawJSON
        )
    }

    private func loadCategoryNamesByUID() async throws -> [String: String] {
        let categories = try await source.listRecipeCategories()
        return Dictionary(
            uniqueKeysWithValues: categories
                .filter { !$0.isDeleted }
                .map { ($0.uid, $0.name) }
        )
    }

    private func resolvedCategories(
        _ references: [String],
        categoryNamesByUID: [String: String]
    ) -> [String] {
        references.map { categoryNamesByUID[$0] ?? $0 }
    }

    private static func sortRecipes(
        lhs: RecipeSummary,
        rhs: RecipeSummary,
        by sort: RecipeListSort
    ) -> Bool {
        switch sort {
        case .name:
            return compareByName(lhs: lhs, rhs: rhs)
        case .rating:
            return compareByRating(lhs: lhs, rhs: rhs)
        }
    }

    private static func compareByName(lhs: RecipeSummary, rhs: RecipeSummary) -> Bool {
        if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
            return lhs.uid < rhs.uid
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func compareByRating(lhs: RecipeSummary, rhs: RecipeSummary) -> Bool {
        let lhsRating = lhs.starRating ?? Int.min
        let rhsRating = rhs.starRating ?? Int.min
        if lhsRating != rhsRating {
            return lhsRating > rhsRating
        }

        if lhs.isFavorite != rhs.isFavorite {
            return lhs.isFavorite && !rhs.isFavorite
        }

        return compareByName(lhs: lhs, rhs: rhs)
    }
}
