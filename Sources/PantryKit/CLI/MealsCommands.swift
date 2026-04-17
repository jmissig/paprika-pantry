import ArgumentParser

public struct MealsCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "meals",
        abstract: "Query local meal data.",
        subcommands: [
            MealsListCommand.self,
        ]
    )

    public init() {}
}

public struct MealsListCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List meals once direct Paprika meal reads land."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "meals list",
            plannedPhase: "Later",
            message: "Direct meal reads are intentionally deferred until after the first recipe read slice."
        )
    }
}
