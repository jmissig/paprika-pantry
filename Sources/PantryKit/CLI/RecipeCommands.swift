import ArgumentParser

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
        try emitStub(
            command: "recipes list",
            plannedPhase: "Phase 2",
            message: "Recipe listing requires a populated local mirror and is not implemented yet."
        )
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
        try emitStub(
            command: "recipes show",
            plannedPhase: "Phase 2",
            message: "Recipe lookup requires a synced local database and is not implemented yet.",
            details: ["selector": selector]
        )
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
            plannedPhase: "Phase 2",
            message: "Recipe search will land with the first local mirror slice.",
            details: ["query": query]
        )
    }
}
