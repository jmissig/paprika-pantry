import Foundation

public struct SourceDoctorReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let sourceKind: PantrySourceKind?
    public let displayName: String?
    public let implementation: String?
    public let credentialSource: String?
    public let sourceLocation: String?
    public let schemaFlavor: String?
    public let accessMode: String?
    public let queryOnly: Bool?
    public let journalMode: String?
    public let hasWriteAheadLogFiles: Bool?
    public let paths: PantryPathReport

    public init(snapshot: PantrySourceDoctorSnapshot, paths: PantryPaths) {
        self.command = "source doctor"
        self.status = snapshot.status.rawValue
        self.message = snapshot.message
        self.sourceKind = snapshot.sourceKind
        self.displayName = snapshot.displayName
        self.implementation = snapshot.implementation
        self.credentialSource = snapshot.credentialSource
        self.sourceLocation = snapshot.sourceLocation
        self.schemaFlavor = snapshot.schemaFlavor
        self.accessMode = snapshot.accessMode
        self.queryOnly = snapshot.queryOnly
        self.journalMode = snapshot.journalMode
        self.hasWriteAheadLogFiles = snapshot.hasWriteAheadLogFiles
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
        ]

        if let sourceKind {
            lines.append("kind: \(sourceKind.rawValue)")
        }

        if let displayName, !displayName.isEmpty {
            lines.append("display_name: \(displayName)")
        }

        if let implementation, !implementation.isEmpty {
            lines.append("implementation: \(implementation)")
        }

        if let credentialSource, !credentialSource.isEmpty {
            lines.append("credential_source: \(credentialSource)")
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
