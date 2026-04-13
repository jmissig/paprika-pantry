import ArgumentParser
import Foundation

public struct RecipesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "recipes",
        abstract: "Query the local recipe mirror.",
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
        abstract: "List locally mirrored recipes."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeStore()
        try context.write(RecipesListReport(recipes: try store.listRecipes()))
    }
}

public struct RecipesShowCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show one recipe by UID or name."
    )

    @Argument(help: "Recipe UID or name.")
    public var selector: String

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeStore()
        let recipe = try resolveRecipe(selector: selector, store: store)
        try context.write(RecipeShowReport(recipe: recipe))
    }
}

public struct RecipesSearchCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search locally mirrored recipes."
    )

    @Argument(help: "Search query.")
    public var query: String

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "recipes search",
            plannedPhase: "Later",
            message: "Recipe search is intentionally deferred until after the first trustworthy local mirror slice.",
            details: ["query": query]
        )
    }
}

enum RecipesCommandError: Error, LocalizedError {
    case recipeNotFound(String)
    case ambiguousRecipeName(String, [String])

    var errorDescription: String? {
        switch self {
        case .recipeNotFound(let selector):
            return "No local recipe matched `\(selector)`. Run `paprika-pantry sync run` first if needed."
        case .ambiguousRecipeName(let selector, let matchingUIDs):
            return "Recipe name `\(selector)` matched multiple local recipes. Use a UID instead: \(matchingUIDs.joined(separator: ", "))"
        }
    }
}

func resolveRecipe(selector: String, store: PantryStore) throws -> MirroredRecipe {
    if let recipe = try store.fetchRecipe(uid: selector) {
        return recipe
    }

    let nameMatches = try store.fetchRecipes(namedExactlyCaseInsensitive: selector)
    guard !nameMatches.isEmpty else {
        throw RecipesCommandError.recipeNotFound(selector)
    }

    guard nameMatches.count == 1 else {
        throw RecipesCommandError.ambiguousRecipeName(selector, nameMatches.map(\.uid))
    }

    return nameMatches[0]
}
