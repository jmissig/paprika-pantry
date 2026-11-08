import Foundation

public struct SourceStatusReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let sourceType: String?
    public let displayName: String?
    public let implementation: String?
    public let sourceLocation: String?
    public let capabilities: [String]?
    public let structuralDigest: String?
    public let schemaFlavor: String?
    public let accessMode: String?
    public let queryOnly: Bool?
    public let journalMode: String?
    public let hasWriteAheadLogFiles: Bool?
    public let paprikaSync: PaprikaSyncDetails?
    public let paprikaSyncFreshnessSeconds: Int?
    public let appInstallation: PaprikaAppInstallation?
    public let paths: PantryPathReport

    public init(snapshot: PantrySourceDoctorSnapshot, paths: PantryPaths, now: Date) {
        self.command = "source status"
        self.status = snapshot.status.rawValue
        self.message = snapshot.message
        self.sourceType = snapshot.sourceType
        self.displayName = snapshot.displayName
        self.implementation = snapshot.implementation
        self.sourceLocation = snapshot.sourceLocation
        self.capabilities = snapshot.capabilities
        self.structuralDigest = snapshot.structuralDigest
        self.schemaFlavor = snapshot.schemaFlavor
        self.accessMode = snapshot.accessMode
        self.queryOnly = snapshot.queryOnly
        self.journalMode = snapshot.journalMode
        self.hasWriteAheadLogFiles = snapshot.hasWriteAheadLogFiles
        self.paprikaSync = snapshot.paprikaSync
        self.paprikaSyncFreshnessSeconds = snapshot.paprikaSync.map {
            max(0, Int(now.timeIntervalSince($0.lastSyncAt)))
        }
        self.appInstallation = snapshot.appInstallation
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
        ]

        if let sourceType, !sourceType.isEmpty {
            lines.append("source_type: \(sourceType)")
        }

        if let displayName, !displayName.isEmpty {
            lines.append("display_name: \(displayName)")
        }

        if let implementation, !implementation.isEmpty {
            lines.append("implementation: \(implementation)")
        }

        if let sourceLocation, !sourceLocation.isEmpty {
            lines.append("source_location: \(sourceLocation)")
        }

        if let schemaFlavor, !schemaFlavor.isEmpty {
            lines.append("schema: \(schemaFlavor)")
        }

        if let capabilities { lines.append("capabilities: \(capabilities.joined(separator: ", "))") }
        if let structuralDigest { lines.append("structural_digest: \(structuralDigest)") }

        if let accessMode, !accessMode.isEmpty {
            lines.append("access_mode: \(accessMode)")
        }

        if let queryOnly {
            lines.append("query_only: \(queryOnly ? "yes" : "no")")
        }

        if let journalMode, !journalMode.isEmpty {
            lines.append("journal_mode: \(journalMode)")
        }

        if let hasWriteAheadLogFiles {
            lines.append("wal_files: \(hasWriteAheadLogFiles ? "present" : "absent")")
        }

        lines.append(contentsOf: renderedPaprikaSyncLines(
            sync: paprikaSync,
            prefix: "paprika",
            freshnessSeconds: paprikaSyncFreshnessSeconds
        ))
        lines.append(contentsOf: renderedPaprikaAppInstallationLines(appInstallation))
        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct SourceStatsReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let recipeStubCount: Int
    public let activeRecipeCount: Int
    public let deletedRecipeCount: Int
    public let categoryCount: Int
    public let activeCategoryCount: Int
    public let deletedCategoryCount: Int
    public let recipeFieldCoverage: SourceRecipeFieldCoverage
    public let sampleLimit: Int
    public let sampledRecipeCount: Int
    public let sampleFailureCount: Int
    public let sampledRecipes: [SourceRecipeSample]
    public let sampleFailures: [SourceRecipeSampleFailure]
    public let paths: PantryPathReport

    public init(snapshot: SourceStatsSnapshot, paths: PantryPaths) {
        self.command = "source stats"
        self.status = snapshot.sampleFailureCount == 0 ? "ok" : "partial"
        self.message = snapshot.sampleFailureCount == 0
            ? "Direct source counts loaded and sampled recipe coverage succeeded."
            : "Direct source counts loaded, but sampled recipe coverage had failures."
        self.recipeStubCount = snapshot.recipeStubCount
        self.activeRecipeCount = snapshot.activeRecipeCount
        self.deletedRecipeCount = snapshot.deletedRecipeCount
        self.categoryCount = snapshot.categoryCount
        self.activeCategoryCount = snapshot.activeCategoryCount
        self.deletedCategoryCount = snapshot.deletedCategoryCount
        self.recipeFieldCoverage = snapshot.recipeFieldCoverage
        self.sampleLimit = snapshot.sampleLimit
        self.sampledRecipeCount = snapshot.sampledRecipeCount
        self.sampleFailureCount = snapshot.sampleFailureCount
        self.sampledRecipes = snapshot.sampledRecipes
        self.sampleFailures = snapshot.sampleFailures
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
            "recipes_total: \(recipeStubCount)",
            "recipes_active: \(activeRecipeCount)",
            "recipes_deleted: \(deletedRecipeCount)",
            "categories_total: \(categoryCount)",
            "categories_active: \(activeCategoryCount)",
            "categories_deleted: \(deletedCategoryCount)",
            "recipes_with_description: \(recipeFieldCoverage.descriptionCount)",
            "recipes_with_notes: \(recipeFieldCoverage.notesCount)",
            "recipes_with_description_and_notes: \(recipeFieldCoverage.descriptionAndNotesCount)",
            "recipes_with_difficulty: \(recipeFieldCoverage.difficultyCount)",
            "recipes_with_nutrition: \(recipeFieldCoverage.nutritionCount)",
            "recipes_with_source_url: \(recipeFieldCoverage.sourceURLCount)",
            "recipes_with_image_url: \(recipeFieldCoverage.imageURLCount)",
            "recipes_with_primary_photo: \(recipeFieldCoverage.primaryPhotoCount)",
            "recipes_with_additional_photos: \(recipeFieldCoverage.recipesWithAdditionalPhotosCount)",
            "additional_photos_total: \(recipeFieldCoverage.additionalPhotoCount)",
            "sample_limit: \(sampleLimit)",
            "sampled_recipes: \(sampledRecipeCount)",
            "sample_failures: \(sampleFailureCount)",
        ]

        for sample in sampledRecipes {
            let categories = sample.categories.isEmpty
                ? "-"
                : sample.categories.joined(separator: ", ")
            lines.append("sample_recipe: \(sample.name) [\(sample.uid)] categories=\(categories)")
        }

        for failure in sampleFailures {
            lines.append("sample_failure: \(failure.name) [\(failure.uid)] error=\(failure.message)")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct DoctorReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let sourceStatus: String
    public let indexStatus: String
    public let sourceType: String?
    public let displayName: String?
    public let implementation: String?
    public let sourceLocation: String?
    public let schemaFlavor: String?
    public let accessMode: String?
    public let queryOnly: Bool?
    public let journalMode: String?
    public let hasWriteAheadLogFiles: Bool?
    public let paprikaSync: PaprikaSyncDetails?
    public let paprikaSyncFreshnessSeconds: Int?
    public let appInstallation: PaprikaAppInstallation?
    public let recipeSearchDocumentCount: Int
    public let recipeSearchFreshnessSeconds: Int?
    public let lastRecipeSearchRunStatus: String?
    public let nextAction: String?
    public let paths: PantryPathReport

    public init(
        sourceSnapshot: PantrySourceDoctorSnapshot,
        indexStats: PantryIndexStats,
        paths: PantryPaths,
        now: Date
    ) {
        let indexFreshnessSeconds = indexStats.lastSuccessfulRecipeSearchRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        let indexStatus: String
        let status: String
        let message: String
        let nextAction: String?

        if sourceSnapshot.status != .ready {
            indexStatus = "blocked"
            status = "blocked"
            message = sourceSnapshot.message
            nextAction = "Make the local Paprika SQLite source readable, then rebuild indexes as needed."
        } else if let issue = indexStats.compatibilityIssue {
            indexStatus = "incompatible"
            status = "needs-rebuild"
            message = issue
            nextAction = "Resolve the reported sidecar issue. A newer-version sidecar requires its compatible binary or a separate --home; otherwise rebuild with the selected source."
        } else if let lastRun = indexStats.lastRecipeSearchRun, lastRun.status == .failed,
                  indexStats.lastSuccessfulRecipeSearchRun == nil {
            indexStatus = "failed"
            status = "needs-index"
            message = "The direct source is ready, but the recipe search index is unavailable because the last rebuild failed."
            nextAction = "Run `paprika-pantry index rebuild` after fixing the source issue."
        } else if let lastRun = indexStats.lastRecipeSearchRun, lastRun.status == .failed {
            indexStatus = "stale"
            status = "stale"
            message = "The direct source is ready, but the last index rebuild failed. Search data is from the previous successful rebuild."
            nextAction = "Run `paprika-pantry index rebuild` to refresh the stale sidecar index."
        } else if indexStats.recipeSearchReady {
            indexStatus = "ready"
            status = "ready"
            message = "The direct source is ready and the recipe search index is available."
            nextAction = nil
        } else {
            indexStatus = "missing"
            status = "needs-index"
            message = "The direct source is ready, but the recipe search index has not been built yet."
            nextAction = "Run `paprika-pantry index rebuild` to populate sidecar search."
        }

        self.command = "doctor"
        self.status = status
        self.message = message
        self.sourceStatus = sourceSnapshot.status.rawValue
        self.indexStatus = indexStatus
        self.sourceType = sourceSnapshot.sourceType
        self.displayName = sourceSnapshot.displayName
        self.implementation = sourceSnapshot.implementation
        self.sourceLocation = sourceSnapshot.sourceLocation
        self.schemaFlavor = sourceSnapshot.schemaFlavor
        self.accessMode = sourceSnapshot.accessMode
        self.queryOnly = sourceSnapshot.queryOnly
        self.journalMode = sourceSnapshot.journalMode
        self.hasWriteAheadLogFiles = sourceSnapshot.hasWriteAheadLogFiles
        self.paprikaSync = sourceSnapshot.paprikaSync
        self.paprikaSyncFreshnessSeconds = sourceSnapshot.paprikaSync.map {
            max(0, Int(now.timeIntervalSince($0.lastSyncAt)))
        }
        self.appInstallation = sourceSnapshot.appInstallation
        self.recipeSearchDocumentCount = indexStats.recipeSearchDocumentCount
        self.recipeSearchFreshnessSeconds = indexFreshnessSeconds
        self.lastRecipeSearchRunStatus = indexStats.lastRecipeSearchRun?.status.rawValue
        self.nextAction = nextAction
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
            "source_status: \(sourceStatus)",
            "index_status: \(indexStatus)",
            "recipe_search_documents: \(recipeSearchDocumentCount)",
        ]

        if let sourceType, !sourceType.isEmpty {
            lines.append("source_type: \(sourceType)")
        }

        if let displayName, !displayName.isEmpty {
            lines.append("display_name: \(displayName)")
        }

        if let implementation, !implementation.isEmpty {
            lines.append("implementation: \(implementation)")
        }

        if let sourceLocation, !sourceLocation.isEmpty {
            lines.append("source_location: \(sourceLocation)")
        }

        if let schemaFlavor, !schemaFlavor.isEmpty {
            lines.append("schema: \(schemaFlavor)")
        }

        if let accessMode, !accessMode.isEmpty {
            lines.append("access_mode: \(accessMode)")
        }

        if let queryOnly {
            lines.append("query_only: \(queryOnly ? "yes" : "no")")
        }

        if let journalMode, !journalMode.isEmpty {
            lines.append("journal_mode: \(journalMode)")
        }

        if let hasWriteAheadLogFiles {
            lines.append("wal_files: \(hasWriteAheadLogFiles ? "present" : "absent")")
        }

        if let lastRecipeSearchRunStatus, !lastRecipeSearchRunStatus.isEmpty {
            lines.append("recipe_search_last_run_status: \(lastRecipeSearchRunStatus)")
        }

        lines.append(contentsOf: renderedPaprikaSyncLines(
            sync: paprikaSync,
            prefix: "paprika",
            freshnessSeconds: paprikaSyncFreshnessSeconds
        ))
        lines.append(contentsOf: renderedPaprikaAppInstallationLines(appInstallation))

        if let recipeSearchFreshnessSeconds {
            lines.append("recipe_search_freshness: \(renderedDuration(seconds: recipeSearchFreshnessSeconds)) old")
        } else {
            lines.append("recipe_search_freshness: never-built")
        }

        if let nextAction, !nextAction.isEmpty {
            lines.append("next_action: \(nextAction)")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

func renderedPaprikaSyncLines(
    sync: PaprikaSyncDetails?,
    prefix: String,
    freshnessSeconds: Int?
) -> [String] {
    guard let sync else {
        return [
            "\(prefix)_sync_freshness: unavailable",
        ]
    }

    var lines = [
        "\(prefix)_last_sync_at: \(renderedTimestamp(sync.lastSyncAt))",
        "\(prefix)_sync_signal_source: \(sync.signalSource)",
        "\(prefix)_sync_signal_location: \(sync.signalLocation)",
    ]

    if let freshnessSeconds {
        lines.insert("\(prefix)_sync_freshness: \(renderedDuration(seconds: freshnessSeconds)) old", at: 1)
    } else {
        lines.insert("\(prefix)_sync_freshness: unavailable", at: 1)
    }

    return lines
}

func renderedPaprikaAppInstallationLines(
    _ appInstallation: PaprikaAppInstallation?
) -> [String] {
    guard let appInstallation else {
        return [
            "paprika_app_bundle: unavailable",
            "launch_for_sync_investigation: no Paprika app bundle was found in standard local app locations",
        ]
    }

    var lines = [
        "paprika_app_bundle: \(appInstallation.appBundlePath)",
    ]

    if let bundleIdentifier = appInstallation.bundleIdentifier, !bundleIdentifier.isEmpty {
        lines.append("paprika_app_bundle_identifier: \(bundleIdentifier)")
    }

    if let executablePath = appInstallation.executablePath, !executablePath.isEmpty {
        lines.append("paprika_app_executable: \(executablePath)")
    }

    lines.append("paprika_app_executable_present: \(appInstallation.executablePresent ? "yes" : "no")")

    if appInstallation.customURLSchemes.isEmpty {
        lines.append("paprika_app_url_schemes: none")
        lines.append("launch_for_sync_investigation: no custom URL scheme was found; manual app open is the only obvious on-disk sync nudge")
    } else {
        lines.append("paprika_app_url_schemes: \(appInstallation.customURLSchemes.joined(separator: ", "))")
        lines.append("launch_for_sync_investigation: custom app URL schemes exist, but sync-on-open remains unverified")
    }

    return lines
}
