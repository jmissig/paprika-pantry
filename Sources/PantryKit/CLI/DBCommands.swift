import ArgumentParser

public struct DBCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "db",
        abstract: "Inspect the local SQLite mirror.",
        subcommands: [
            DBStatsCommand.self,
        ]
    )

    public init() {}
}

public struct DBStatsCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show local database stats."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "db stats",
            plannedPhase: "Phase 2",
            message: "Database stats need a migrated local store and are not implemented yet."
        )
    }
}
