import ArgumentParser
import Foundation

public struct IndexCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Manage owned sidecar search indexes, derived recipe features, usage stats, and ingredient tokens.",
        subcommands: [
            IndexStatsCommand.self,
            IndexRebuildCommand.self,
            IndexUpdateCommand.self,
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
        let store = try context.makeSidecarStore()
        try context.write(IndexStatsReport(stats: try store.indexStats(), paths: context.paths, now: Date()))
    }
}

public struct IndexRebuildCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "rebuild",
        abstract: "Rebuild owned recipe search, feature, usage, and ingredient-token indexes from the configured local Paprika source."
    )

    public init() {}
    public mutating func run() throws {
        try runIndexRefresh()
    }
}

public struct IndexUpdateCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update owned sidecar indexes from the configured local Paprika source. Currently equivalent to `index rebuild`, but kept as a stable surface for future partial updates."
    )

    public init() {}
    public mutating func run() throws {
        try runIndexRefresh()
    }
}

private func performIndexRefresh(using command: some PantryLeafCommand) throws {
    let context = try command.makeContext()
    let source = try context.makeSource()
    let store = try context.makeSidecarStore()
    let summary = try BlockingAsync.run {
        try await store.rebuildRecipeIndexes(from: source)
    }
    try context.write(IndexRebuildReport(summary: summary, paths: context.paths))
}

private extension PantryLeafCommand {
    func runIndexRefresh() throws {
        try performIndexRefresh(using: self)
    }
}
