import ArgumentParser
import Foundation

public struct SyncCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Inspect or refresh the local mirror from a configured source.",
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
        abstract: "Run a sync against the configured pantry source."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeStore()
        let source = try context.makeSourceProvider().makeSource()
        let syncEngine = RecipeMirrorSyncEngine(
            source: source,
            store: store
        )
        let summary = try BlockingAsync.run {
            try await syncEngine.run()
        }

        try context.write(SyncRunReport(summary: summary, paths: context.paths))
    }
}

public struct SyncStatusCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show local sync freshness and status."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeStore()
        let snapshot = try store.syncStatus()
        try context.write(
            SyncStatusReport(snapshot: snapshot, paths: context.paths, now: Date())
        )
    }
}
