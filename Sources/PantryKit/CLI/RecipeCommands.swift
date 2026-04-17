import ArgumentParser
import Foundation

public struct RecipesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "recipes",
        abstract: "Query canonical recipes and sidecar-backed recipe search/features.",
        subcommands: [
            RecipesListCommand.self,
            RecipesShowCommand.self,
            RecipesSearchCommand.self,
            RecipesFeaturesCommand.self,
        ]
    )

    public init() {}
}

public struct RecipesListCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List recipes from the configured pantry source with canonical rating/favorite filters."
    )

    @Flag(name: .long, help: "Only include recipes marked favorite in Paprika.")
    public var favorite: Bool = false

    @Option(name: .long, help: "Only include recipes rated at least this many stars (1-5).")
    public var minRating: Int?

    @Option(name: .long, help: "Only include recipes rated at most this many stars (1-5).")
    public var maxRating: Int?

    @Option(name: .long, help: "Sort order for returned recipes: \(RecipeListSort.allCases.map(\.rawValue).joined(separator: ", ")).")
    public var sort: RecipeListSort = .name

    public init() {}

    public mutating func validate() throws {
        try validateRecipeQueryOptions(minRating: minRating, maxRating: maxRating)
    }

    public mutating func run() throws {
        let context = try makeContext()
        let recipeReadService = try context.makeRecipeReadService()
        let sort = self.sort
        let filters = RecipeQueryFilters(
            favoritesOnly: favorite,
            minRating: minRating,
            maxRating: maxRating
        )
        let recipes = try BlockingAsync.run {
            try await recipeReadService.listRecipes(filters: filters, sort: sort)
        }
        try context.write(RecipesListReport(recipes: recipes, filters: filters, sort: sort))
    }
}

public struct RecipesShowCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show one source recipe by UID or name."
    )

    @Argument(help: "Recipe UID or name.")
    public var selector: String

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let recipeReadService = try context.makeRecipeReadService()
        let selector = self.selector
        let recipe = try BlockingAsync.run {
            try await recipeReadService.resolveRecipe(selector: selector)
        }
        let derivedFeatures = try context.makeStore().fetchRecipeFeatures(uid: recipe.uid)
        try context.write(RecipeShowReport(recipe: recipe, derivedFeatures: derivedFeatures))
    }
}

public struct RecipesSearchCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search recipes through the owned sidecar index with canonical rating/favorite filters."
    )

    @Argument(help: "Search query.")
    public var query: String

    @Flag(name: .long, help: "Only include recipes marked favorite in Paprika.")
    public var favorite: Bool = false

    @Option(name: .long, help: "Only include recipes rated at least this many stars (1-5).")
    public var minRating: Int?

    @Option(name: .long, help: "Only include recipes rated at most this many stars (1-5).")
    public var maxRating: Int?

    @Option(name: .long, help: "Sort order for returned recipes: \(RecipeSearchSort.allCases.map(\.rawValue).joined(separator: ", ")).")
    public var sort: RecipeSearchSort = .relevance

    @Option(name: .long, help: "Maximum results to return.")
    public var limit: Int = 20

    public init() {}

    public mutating func validate() throws {
        try validateRecipeQueryOptions(minRating: minRating, maxRating: maxRating)
    }

    public mutating func run() throws {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw ValidationError("Search query must not be empty.")
        }

        guard limit > 0 else {
            throw ValidationError("--limit must be greater than zero.")
        }

        let context = try makeContext()
        let store = try context.makeStore()
        guard try store.indexStats().recipeSearchReady else {
            throw ValidationError("Recipe search index is not ready. Run `paprika-pantry index rebuild` first.")
        }

        let filters = RecipeQueryFilters(
            favoritesOnly: favorite,
            minRating: minRating,
            maxRating: maxRating
        )
        let results = try store.searchRecipes(query: query, filters: filters, sort: sort, limit: limit)
        try context.write(
            RecipesSearchReport(
                query: query,
                filters: filters,
                sort: sort,
                results: results,
                paths: context.paths
            )
        )
    }
}

public struct RecipesFeaturesCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "features",
        abstract: "Show sidecar-derived recipe time and ingredient-line features for one recipe."
    )

    @Argument(help: "Recipe UID or name.")
    public var selector: String

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeStore()
        guard try store.indexStats().recipeFeaturesReady else {
            throw ValidationError("Recipe feature index is not ready. Run `paprika-pantry index rebuild` first.")
        }

        let recipeReadService = try context.makeRecipeReadService()
        let selector = self.selector
        let recipe = try BlockingAsync.run {
            try await recipeReadService.resolveRecipe(selector: selector)
        }

        guard let features = try store.fetchRecipeFeatures(uid: recipe.uid) else {
            throw ValidationError("No derived feature row exists for recipe `\(recipe.uid)`. Run `paprika-pantry index rebuild` first.")
        }

        try context.write(RecipeFeaturesReport(recipe: recipe, features: features, paths: context.paths))
    }
}

private func validateRecipeQueryOptions(minRating: Int?, maxRating: Int?) throws {
    if let minRating, !(1 ... 5).contains(minRating) {
        throw ValidationError("--min-rating must be between 1 and 5.")
    }

    if let maxRating, !(1 ... 5).contains(maxRating) {
        throw ValidationError("--max-rating must be between 1 and 5.")
    }

    if let minRating, let maxRating, minRating > maxRating {
        throw ValidationError("--min-rating must be less than or equal to --max-rating.")
    }
}
