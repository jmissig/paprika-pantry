import ArgumentParser
import Foundation

public struct RecipesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "recipes",
        abstract: "Query canonical recipes and sidecar-backed recipe search.",
        subcommands: [
            RecipesListCommand.self,
            RecipesShowCommand.self,
            RecipesSearchCommand.self,
        ]
    )

    public init() {}
}

public struct RecipesListCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List recipes from the configured pantry source."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let recipeReadService = try context.makeRecipeReadService()
        let recipes = try BlockingAsync.run {
            try await recipeReadService.listRecipes()
        }
        try context.write(RecipesListReport(recipes: recipes))
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
        try context.write(RecipeShowReport(recipe: recipe))
    }
}

public struct RecipesSearchCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search recipes through the owned sidecar index."
    )

    @Argument(help: "Search query.")
    public var query: String

    @Option(name: .long, help: "Maximum results to return.")
    public var limit: Int = 20

    public init() {}
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

        let results = try store.searchRecipes(query: query, limit: limit)
        try context.write(RecipesSearchReport(query: query, results: results, paths: context.paths))
    }
}
