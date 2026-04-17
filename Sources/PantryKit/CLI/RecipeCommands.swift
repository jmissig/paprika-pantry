import ArgumentParser
import Foundation

public struct RecipesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "recipes",
        abstract: "Query recipe data from the configured pantry source.",
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
        abstract: "Search recipes once sidecar indexing is available."
    )

    @Argument(help: "Search query.")
    public var query: String

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "recipes search",
            plannedPhase: "Later",
            message: "Recipe search is intentionally deferred until the first owned sidecar index slice lands.",
            details: ["query": query]
        )
    }
}
