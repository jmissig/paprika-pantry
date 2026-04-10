import ArgumentParser

public struct GroceriesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "groceries",
        abstract: "Query the local groceries mirror.",
        subcommands: [
            GroceriesListCommand.self,
        ]
    )

    public init() {}
}

public struct GroceriesListCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List locally mirrored groceries."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "groceries list",
            plannedPhase: "Later",
            message: "Groceries mirror support is intentionally deferred until after the first recipe mirror slice."
        )
    }
}
