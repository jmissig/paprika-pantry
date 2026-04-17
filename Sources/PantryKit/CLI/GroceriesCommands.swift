import ArgumentParser

public struct GroceriesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "groceries",
        abstract: "Query local grocery data.",
        subcommands: [
            GroceriesListCommand.self,
        ]
    )

    public init() {}
}

public struct GroceriesListCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List groceries once direct Paprika grocery reads land."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "groceries list",
            plannedPhase: "Later",
            message: "Direct grocery reads are intentionally deferred until after the first recipe read slice."
        )
    }
}
