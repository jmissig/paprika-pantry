import Foundation

public struct SourceRecipeSample: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]

    public init(uid: String, name: String, categories: [String]) {
        self.uid = uid
        self.name = name
        self.categories = categories
    }
}

public struct SourceRecipeSampleFailure: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let message: String

    public init(uid: String, name: String, message: String) {
        self.uid = uid
        self.name = name
        self.message = message
    }
}

public struct SourceStatsSnapshot: Codable, Equatable, Sendable {
    public let recipeStubCount: Int
    public let activeRecipeCount: Int
    public let deletedRecipeCount: Int
    public let categoryCount: Int
    public let activeCategoryCount: Int
    public let deletedCategoryCount: Int
    public let sampleLimit: Int
    public let sampledRecipeCount: Int
    public let sampleFailureCount: Int
    public let sampledRecipes: [SourceRecipeSample]
    public let sampleFailures: [SourceRecipeSampleFailure]

    public init(
        recipeStubCount: Int,
        activeRecipeCount: Int,
        deletedRecipeCount: Int,
        categoryCount: Int,
        activeCategoryCount: Int,
        deletedCategoryCount: Int,
        sampleLimit: Int,
        sampledRecipeCount: Int,
        sampleFailureCount: Int,
        sampledRecipes: [SourceRecipeSample],
        sampleFailures: [SourceRecipeSampleFailure]
    ) {
        self.recipeStubCount = recipeStubCount
        self.activeRecipeCount = activeRecipeCount
        self.deletedRecipeCount = deletedRecipeCount
        self.categoryCount = categoryCount
        self.activeCategoryCount = activeCategoryCount
        self.deletedCategoryCount = deletedCategoryCount
        self.sampleLimit = sampleLimit
        self.sampledRecipeCount = sampledRecipeCount
        self.sampleFailureCount = sampleFailureCount
        self.sampledRecipes = sampledRecipes
        self.sampleFailures = sampleFailures
    }
}

public struct SourceStatsService: Sendable {
    private let source: any PantrySource
    private let recipeReadService: RecipeReadService

    public init(source: any PantrySource) {
        self.source = source
        self.recipeReadService = RecipeReadService(source: source)
    }

    public func makeSnapshot(sampleLimit: Int) async throws -> SourceStatsSnapshot {
        let stubs = try await source.listRecipeStubs()
        let categories = try await source.listRecipeCategories()
        let activeStubs = stubs
            .filter { !$0.isDeleted }
            .sorted(by: Self.sortRecipeStubs)

        let sampleStubs = Array(activeStubs.prefix(sampleLimit))
        var sampledRecipes = [SourceRecipeSample]()
        var sampleFailures = [SourceRecipeSampleFailure]()

        sampledRecipes.reserveCapacity(sampleStubs.count)
        sampleFailures.reserveCapacity(sampleStubs.count)

        for stub in sampleStubs {
            do {
                let recipe = try await recipeReadService.resolveRecipe(selector: stub.uid)
                sampledRecipes.append(
                    SourceRecipeSample(
                        uid: recipe.uid,
                        name: recipe.name,
                        categories: recipe.categories
                    )
                )
            } catch {
                sampleFailures.append(
                    SourceRecipeSampleFailure(
                        uid: stub.uid,
                        name: stub.name,
                        message: error.localizedDescription
                    )
                )
            }
        }

        let deletedRecipeCount = stubs.count - activeStubs.count
        let activeCategoryCount = categories.count { !$0.isDeleted }
        let deletedCategoryCount = categories.count - activeCategoryCount

        return SourceStatsSnapshot(
            recipeStubCount: stubs.count,
            activeRecipeCount: activeStubs.count,
            deletedRecipeCount: deletedRecipeCount,
            categoryCount: categories.count,
            activeCategoryCount: activeCategoryCount,
            deletedCategoryCount: deletedCategoryCount,
            sampleLimit: sampleLimit,
            sampledRecipeCount: sampledRecipes.count,
            sampleFailureCount: sampleFailures.count,
            sampledRecipes: sampledRecipes,
            sampleFailures: sampleFailures
        )
    }

    private static func sortRecipeStubs(lhs: SourceRecipeStub, rhs: SourceRecipeStub) -> Bool {
        if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
            return lhs.uid < rhs.uid
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
