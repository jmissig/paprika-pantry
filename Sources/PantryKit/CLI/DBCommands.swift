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
        let context = try makeContext()
        let store = try context.makeStore()
        try context.write(DBStatsReport(stats: try store.stats(), paths: context.paths))
    }
}
