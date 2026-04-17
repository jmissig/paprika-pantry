import ArgumentParser
import Foundation

public struct IndexCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Manage owned sidecar indexes, derived recipe features, and ingredient tokens.",
        subcommands: [
            IndexStatsCommand.self,
            IndexRebuildCommand.self,
        ]
    )

    public init() {}
}

public struct IndexStatsCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show sidecar index status."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeStore()
        try context.write(IndexStatsReport(stats: try store.indexStats(), paths: context.paths, now: Date()))
    }
}

public struct IndexRebuildCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "rebuild",
        abstract: "Rebuild owned recipe search, feature, and ingredient-token indexes from the configured local Paprika source."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let source = try context.makeSource()
        let store = try context.makeStore()
        let summary = try BlockingAsync.run {
            try await store.rebuildRecipeIndexes(from: source)
        }
        try context.write(IndexRebuildReport(summary: summary, paths: context.paths))
    }
}
