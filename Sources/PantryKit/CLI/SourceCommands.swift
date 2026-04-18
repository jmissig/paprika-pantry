import ArgumentParser
import Foundation

public struct SourceCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "source",
        abstract: "Inspect direct Paprika SQLite source readiness.",
        subcommands: [
            SourceDoctorCommand.self,
            SourceStatsCommand.self,
            SourceCookbooksCommand.self,
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
        try context.write(SourceDoctorReport(snapshot: snapshot, paths: context.paths, now: Date()))
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

public struct SourceCookbooksCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "cookbooks",
        abstract: "Show sidecar-backed cookbook/source aggregates from canonical recipe source fields."
    )

    @Option(name: .long, help: "Sort order for cookbook/source groups: \(CookbookAggregateSort.allCases.map(\.rawValue).joined(separator: ", ")).")
    public var sort: CookbookAggregateSort = .averageRating

    @Option(name: .long, help: "Maximum number of cookbook/source groups to return.")
    public var limit: Int = 20

    @Option(name: .customLong("min-recipes"), help: "Only include cookbook/source groups with at least this many recipes.")
    public var minRecipes: Int = 1

    @Option(name: .customLong("min-rated-recipes"), help: "Only include cookbook/source groups with at least this many rated recipes.")
    public var minRatedRecipes: Int = 0

    public init() {}

    public mutating func run() throws {
        guard limit > 0 else {
            throw ValidationError("--limit must be greater than zero.")
        }

        guard minRecipes >= 1 else {
            throw ValidationError("--min-recipes must be at least 1.")
        }

        guard minRatedRecipes >= 0 else {
            throw ValidationError("--min-rated-recipes must be zero or greater.")
        }

        let context = try makeContext()
        let store = try context.makeStore()
        let indexStats = try store.indexStats()

        guard indexStats.recipeSearchReady else {
            throw ValidationError("Cookbook/source aggregates require the recipe search index. Run `paprika-pantry index rebuild` first.")
        }

        let aggregates = try store.listCookbookAggregates(
            sort: sort,
            limit: limit,
            minRecipeCount: minRecipes,
            minRatedRecipeCount: minRatedRecipes
        )
        try context.write(
            SourceCookbooksReport(
                aggregates: aggregates,
                sort: sort,
                limit: limit,
                minRecipeCount: minRecipes,
                minRatedRecipeCount: minRatedRecipes,
                indexStats: indexStats,
                paths: context.paths,
                now: Date()
            )
        )
    }
}
