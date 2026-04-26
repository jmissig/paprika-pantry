import ArgumentParser
import Foundation

public struct SourceCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "source",
        abstract: "Inspect direct Paprika SQLite source readiness.",
        subcommands: [
            SourceDoctorCommand.self,
            SourceLastSyncTimeCommand.self,
            SourceStatsCommand.self,
            SourceCookbooksCommand.self,
            SourceLaunchAppCommand.self,
        ]
    )

    public init() {}
}

public struct SourceLaunchAppCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "launch-app",
        abstract: "Launch the local Paprika app. This does not sync directly, but Paprika may sync on launch."
    )

    @Flag(name: .customLong("wait-for-sync"), help: "After launching, wait for the observed Paprika last-sync timestamp to advance.")
    public var waitForSync = false

    @Option(name: .customLong("timeout-seconds"), help: "Maximum seconds to wait for an observed sync advance after launch.")
    public var timeoutSeconds: Int = 180

    @Option(name: .customLong("poll-interval"), help: "Seconds between sync-state checks while waiting.")
    public var pollInterval: Double = 2

    public init() {}

    public mutating func run() throws {
        guard timeoutSeconds >= 0 else {
            throw ValidationError("--timeout-seconds must be zero or greater.")
        }

        guard pollInterval > 0 else {
            throw ValidationError("--poll-interval must be greater than zero.")
        }

        let context = try makeContext()
        let snapshot = try context.makeSourceProvider().diagnose()

        guard let appInstallation = snapshot.appInstallation else {
            throw ValidationError("No local Paprika app bundle was found in standard app locations.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appInstallation.appBundlePath]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ValidationError("Failed to launch Paprika.app via `open -a`. \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            throw ValidationError("Launching Paprika.app exited with status \(process.terminationStatus).")
        }

        let initialPaprikaSync = snapshot.paprikaSync
        var observedPaprikaSync = snapshot.paprikaSync
        var syncAdvanced: Bool? = nil
        var status = "launched"
        var message = "Launched the local Paprika app."
        var effect = "This does not trigger a direct sync command. It only opens Paprika, which may sync as part of normal app launch behavior."
        var observedSyncFreshnessSeconds: Int? = nil

        if waitForSync {
            let waitResult = try waitForPaprikaSyncAdvance(
                context: context,
                initialPaprikaSync: initialPaprikaSync,
                timeoutSeconds: timeoutSeconds,
                pollInterval: pollInterval
            )
            observedPaprikaSync = waitResult.snapshot.paprikaSync
            syncAdvanced = waitResult.syncAdvanced
            observedSyncFreshnessSeconds = waitResult.snapshot.paprikaSync.map {
                max(0, Int(waitResult.observedAt.timeIntervalSince($0.lastSyncAt)))
            }

            if waitResult.syncAdvanced {
                status = "launched-and-sync-advanced"
                message = "Launched the local Paprika app and observed the Paprika last-sync timestamp advance."
                effect = "This still does not call a direct sync API. It launches Paprika, then waits for the locally observed last-sync marker to move forward."
            } else {
                status = "launched-no-sync-advance-observed"
                message = "Launched the local Paprika app, but did not observe the Paprika last-sync timestamp advance before timeout."
                effect = "This still does not call a direct sync API. It launches Paprika and watches local metadata, which may lag or remain unchanged if Paprika was already current."
            }
        }

        try context.write(
            AppLaunchReport(
                command: "source launch-app",
                status: status,
                message: message,
                effect: effect,
                appBundlePath: appInstallation.appBundlePath,
                bundleIdentifier: appInstallation.bundleIdentifier,
                launchedVia: "open -a",
                waitedForSync: waitForSync,
                waitTimeoutSeconds: waitForSync ? timeoutSeconds : nil,
                pollIntervalSeconds: waitForSync ? pollInterval : nil,
                initialPaprikaSync: waitForSync ? initialPaprikaSync : nil,
                observedPaprikaSync: waitForSync ? observedPaprikaSync : nil,
                syncAdvanced: syncAdvanced,
                observedSyncFreshnessSeconds: observedSyncFreshnessSeconds,
                paths: context.paths
            )
        )
    }
}

public struct SourceLastSyncTimeCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "last-sync-time",
        abstract: "Show the last observed Paprika sync completion time from local metadata."
    )

    public init() {}

    public mutating func run() throws {
        let context = try makeContext()
        let snapshot = try context.makeSourceProvider().diagnose()
        try context.write(SourceLastSyncReport(snapshot: snapshot, paths: context.paths, now: Date()))
    }
}

private func waitForPaprikaSyncAdvance(
    context: CommandContext,
    initialPaprikaSync: PaprikaSyncDetails?,
    timeoutSeconds: Int,
    pollInterval: Double
) throws -> (snapshot: PantrySourceDoctorSnapshot, observedAt: Date, syncAdvanced: Bool) {
    let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
    var latestSnapshot = try context.makeSourceProvider().diagnose()
    var observedAt = Date()

    while true {
        observedAt = Date()
        latestSnapshot = try context.makeSourceProvider().diagnose()

        if paprikaSyncHasAdvanced(initial: initialPaprikaSync, observed: latestSnapshot.paprikaSync) {
            return (latestSnapshot, observedAt, true)
        }

        if observedAt >= deadline {
            return (latestSnapshot, observedAt, false)
        }

        Thread.sleep(forTimeInterval: min(pollInterval, max(0, deadline.timeIntervalSince(observedAt))))
    }
}

private func paprikaSyncHasAdvanced(
    initial: PaprikaSyncDetails?,
    observed: PaprikaSyncDetails?
) -> Bool {
    switch (initial, observed) {
    case (.none, .some):
        return true
    case let (.some(initial), .some(observed)):
        return observed.lastSyncAt > initial.lastSyncAt
    default:
        return false
    }
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
        let store = try context.makeSidecarStore()
        let indexStats = try store.indexStats()

        guard indexStats.recipeSearchReady else {
            throw ValidationError("Cookbook/source aggregates require the recipe search index. Run `paprika-pantry index rebuild` first.")
        }

        guard indexStats.recipeUsageStatsReady else {
            throw ValidationError("Cookbook/source usage summaries require the recipe usage index. Run `paprika-pantry index rebuild` first.")
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
