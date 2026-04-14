import ArgumentParser

public struct SourceCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "source",
        abstract: "Inspect pantry source configuration and readiness.",
        subcommands: [
            SourceDoctorCommand.self,
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
