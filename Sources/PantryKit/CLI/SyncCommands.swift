import ArgumentParser
import Foundation

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
        let context = try makeContext()
        let session = try requireSession(context: context)
        let store = try context.makeStore()
        let syncEngine = RecipeMirrorSyncEngine(
            source: PaprikaTokenRemoteClient(token: session.token),
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

private enum SyncCommandError: Error, LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No local Paprika session is saved. Run `paprika-pantry auth login` first."
        }
    }
}

private func requireSession(context: CommandContext) throws -> PantrySession {
    guard let session = try context.makeAuthStore().loadSession() else {
        throw SyncCommandError.notAuthenticated
    }

    return session
}
