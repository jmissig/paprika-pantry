import ArgumentParser
import Foundation

public struct IndexCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Manage owned sidecar search indexes, derived recipe features, usage stats, ingredient tokens, and rebuild-only pairing evidence.",
        discussion: "Use `index update` for the routine refresh path: recipe search, derived features, usage stats, and ingredient-token indexes. Use `index rebuild` for a full refresh that also recomputes the heavier ingredient token-pair evidence used by `recipes pairings`.",
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
        abstract: "Fully rebuild owned sidecar indexes, including heavier ingredient token-pair evidence for `recipes pairings`."
    )

    public init() {}
    public mutating func run() throws {
        try runIndexRefresh(commandName: "index rebuild", refreshIngredientPairEvidence: true)
    }
}

public struct IndexUpdateCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Refresh routine owned sidecar indexes without recomputing ingredient token-pair evidence.",
        discussion: "Updates recipe search, derived recipe features, usage stats, and ingredient-token indexes from the configured local Paprika source. Existing `recipes pairings` evidence is left untouched; run `index rebuild` when you intentionally want to refresh that heavier pairing evidence."
    )

    public init() {}
    public mutating func run() throws {
        try runIndexRefresh(commandName: "index update", refreshIngredientPairEvidence: false)
    }
}

private func performIndexRefresh(
    using command: some PantryLeafCommand,
    commandName: String,
    refreshIngredientPairEvidence: Bool
) throws {
    let context = try command.makeContext()
    let source = try context.makeSource()
    let store = try context.makeSidecarStore()
    let summary = try BlockingAsync.run {
        try await store.rebuildRecipeIndexes(from: source, refreshIngredientPairEvidence: refreshIngredientPairEvidence)
    }
    try context.write(IndexRebuildReport(command: commandName, summary: summary, paths: context.paths))
}

private extension PantryLeafCommand {
    func runIndexRefresh(commandName: String, refreshIngredientPairEvidence: Bool) throws {
        try performIndexRefresh(using: self, commandName: commandName, refreshIngredientPairEvidence: refreshIngredientPairEvidence)
    }
}
