import ArgumentParser

public struct MealsCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "meals",
        abstract: "Query the local meals mirror.",
        subcommands: [
            MealsListCommand.self,
        ]
    )

    public init() {}
}

public struct MealsListCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List locally mirrored meals."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "meals list",
            plannedPhase: "Later",
            message: "Meals mirror support is intentionally deferred until after the first recipe mirror slice."
        )
    }
}
