import ArgumentParser

public struct SourceCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "source",
        abstract: "Inspect direct Paprika SQLite source readiness.",
        subcommands: [
            SourceDoctorCommand.self,
            SourceStatsCommand.self,
        ]
    )

    public init() {}
}

public struct SourceDoctorCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose the configured pantry source."
    )

    public init() {}

    public mutating func run() throws {
        let context = try makeContext()
        let snapshot = try context.makeSourceProvider().diagnose()
        try context.write(SourceDoctorReport(snapshot: snapshot, paths: context.paths))
    }
}

public struct SourceStatsCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show direct source counts and sampled recipe coverage."
    )

    @Option(name: .long, help: "How many active recipes to sample for direct fetch verification.")
    public var sample = 5

    public init() {}

    public mutating func run() throws {
        guard sample >= 0 else {
            throw ValidationError("--sample must be zero or greater.")
        }

        let context = try makeContext()
        let sampleLimit = sample
        let sourceStatsService = try context.makeSourceStatsService()
        let snapshot = try BlockingAsync.run {
            try await sourceStatsService.makeSnapshot(sampleLimit: sampleLimit)
        }
        try context.write(SourceStatsReport(snapshot: snapshot, paths: context.paths))
    }
}
