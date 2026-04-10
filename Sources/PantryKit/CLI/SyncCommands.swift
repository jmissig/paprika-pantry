import ArgumentParser

public struct SyncCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Inspect or refresh the local mirror.",
        subcommands: [
            SyncRunCommand.self,
            SyncStatusCommand.self,
        ]
    )

    public init() {}
}

public struct SyncRunCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a sync against Paprika."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "sync run",
            plannedPhase: "Phase 2",
            message: "Remote fetch and local mirror sync are intentionally deferred until the next phase."
        )
    }
}

public struct SyncStatusCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show local sync freshness and status."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "sync status",
            plannedPhase: "Phase 2",
            message: "Sync status depends on recorded sync runs and is not available yet."
        )
    }
}
