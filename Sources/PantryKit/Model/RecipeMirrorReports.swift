import Foundation

public struct SyncRunReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let startedAt: Date
    public let finishedAt: Date
    public let recipesSeen: Int
    public let recipesChanged: Int
    public let recipesDeleted: Int
    public let paths: PantryPathReport

    public init(summary: SyncSummary, paths: PantryPaths) {
        self.command = "sync run"
        self.status = summary.status.rawValue
        self.message = "Updated the local recipe mirror."
        self.startedAt = summary.startedAt
        self.finishedAt = summary.finishedAt
        self.recipesSeen = summary.recipesSeen
        self.recipesChanged = summary.changedRecipeCount
        self.recipesDeleted = summary.deletedRecipeCount
        self.paths = paths.report
    }

    public var humanDescription: String {
        [
            "\(command): \(message)",
            "status: \(status)",
            "started_at: \(renderedTimestamp(startedAt))",
            "finished_at: \(renderedTimestamp(finishedAt))",
            "recipes_seen: \(recipesSeen)",
            "recipes_changed: \(recipesChanged)",
            "recipes_deleted: \(recipesDeleted)",
            renderedPaths(paths),
        ].joined(separator: "\n")
    }
}

public struct SyncStatusReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let hasSuccessfulSync: Bool
    public let lastAttempt: PantrySyncRun?
    public let lastSuccess: PantrySyncRun?
    public let totalRecipeCount: Int
    public let activeRecipeCount: Int
    public let deletedRecipeCount: Int
    public let freshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(snapshot: PantrySyncStatusSnapshot, paths: PantryPaths, now: Date) {
        let freshnessSeconds = snapshot.lastSuccess.map { max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt))) }
        let status: String
        let message: String

        if snapshot.lastAttempt == nil {
            status = "never-synced"
            message = "The local mirror has not synced yet."
        } else if snapshot.lastAttempt?.status == .failed, snapshot.lastSuccess == nil {
            status = "failed"
            message = "The last sync attempt failed and no successful mirror exists yet."
        } else if snapshot.lastAttempt?.status == .failed {
            status = "stale"
            message = "The last sync attempt failed; local data is from the previous successful sync."
        } else {
            status = "current"
            message = "The local recipe mirror has a recorded successful sync."
        }

        self.command = "sync status"
        self.status = status
        self.message = message
        self.hasSuccessfulSync = snapshot.hasSuccessfulSync
        self.lastAttempt = snapshot.lastAttempt
        self.lastSuccess = snapshot.lastSuccess
        self.totalRecipeCount = snapshot.totalRecipeCount
        self.activeRecipeCount = snapshot.activeRecipeCount
        self.deletedRecipeCount = snapshot.deletedRecipeCount
        self.freshnessSeconds = freshnessSeconds
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
            "recipes_total: \(totalRecipeCount)",
            "recipes_active: \(activeRecipeCount)",
            "recipes_deleted: \(deletedRecipeCount)",
        ]

        if let lastAttempt {
            lines.append("last_attempt_at: \(renderedTimestamp(lastAttempt.startedAt))")
            lines.append("last_attempt_status: \(lastAttempt.status.rawValue)")
        }

        if let lastSuccess {
            lines.append("last_success_at: \(renderedTimestamp(lastSuccess.finishedAt ?? lastSuccess.startedAt))")
        }

        if let lastFailure = lastAttempt, lastFailure.status == .failed, let errorMessage = lastFailure.errorMessage {
            lines.append("last_failure: \(errorMessage)")
        }

        if let freshnessSeconds {
            lines.append("freshness: \(renderedDuration(seconds: freshnessSeconds)) old")
        } else {
            lines.append("freshness: never-synced")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct RecipesListReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let recipeCount: Int
    public let recipes: [RecipeSummary]

    public init(recipes: [RecipeSummary], readPath: String = "direct-source") {
        self.command = "recipes list"
        self.readPath = readPath
        self.recipeCount = recipes.count
        self.recipes = recipes
    }

    public var humanDescription: String {
        var lines = ["\(command): \(recipeCount) recipes", "read_path: \(readPath)"]

        if recipes.isEmpty {
            lines.append("No source recipes found.")
            return lines.joined(separator: "\n")
        }

        for recipe in recipes {
            var parts = ["\(recipe.uid)  \(recipe.name)"]

            if !recipe.categories.isEmpty {
                parts.append("categories=\(recipe.categories.joined(separator: ", "))")
            }

            if let sourceName = recipe.sourceName, !sourceName.isEmpty {
                parts.append("source=\(sourceName)")
            }

            if let starRating = recipe.starRating {
                parts.append("rating=\(starRating)")
            }

            if recipe.isFavorite {
                parts.append("favorite=yes")
            }

            lines.append(parts.joined(separator: " | "))
        }

        return lines.joined(separator: "\n")
    }
}

public struct RecipeShowReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let recipe: RecipeDetail

    public init(recipe: RecipeDetail, readPath: String = "direct-source") {
        self.command = "recipes show"
        self.readPath = readPath
        self.recipe = recipe
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(recipe.name)",
            "read_path: \(readPath)",
            "uid: \(recipe.uid)",
        ]

        if !recipe.categories.isEmpty {
            lines.append("categories: \(recipe.categories.joined(separator: ", "))")
        }

        if let sourceName = recipe.sourceName, !sourceName.isEmpty {
            lines.append("source_name: \(sourceName)")
        }

        if let starRating = recipe.starRating {
            lines.append("star_rating: \(starRating)")
        }

        lines.append("favorite: \(recipe.isFavorite ? "yes" : "no")")

        if let prepTime = recipe.prepTime, !prepTime.isEmpty {
            lines.append("prep_time: \(prepTime)")
        }
        if let cookTime = recipe.cookTime, !cookTime.isEmpty {
            lines.append("cook_time: \(cookTime)")
        }
        if let totalTime = recipe.totalTime, !totalTime.isEmpty {
            lines.append("total_time: \(totalTime)")
        }
        if let servings = recipe.servings, !servings.isEmpty {
            lines.append("servings: \(servings)")
        }
        if let createdAt = recipe.createdAt, !createdAt.isEmpty {
            lines.append("created_at: \(createdAt)")
        }
        if let updatedAt = recipe.updatedAt, !updatedAt.isEmpty {
            lines.append("updated_at: \(updatedAt)")
        }
        if let remoteHash = recipe.remoteHash, !remoteHash.isEmpty {
            lines.append("remote_hash: \(remoteHash)")
        }

        if let ingredients = recipe.ingredients, !ingredients.isEmpty {
            lines.append("ingredients:")
            lines.append(ingredients)
        }

        if let directions = recipe.directions, !directions.isEmpty {
            lines.append("directions:")
            lines.append(directions)
        }

        if let notes = recipe.notes, !notes.isEmpty {
            lines.append("notes:")
            lines.append(notes)
        }

        return lines.joined(separator: "\n")
    }
}

public struct DBStatsReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let stats: PantryDatabaseStats
    public let paths: PantryPathReport

    public init(stats: PantryDatabaseStats, paths: PantryPaths) {
        self.command = "db stats"
        self.stats = stats
        self.paths = paths.report
    }

    public var humanDescription: String {
        [
            "\(command): Local mirror counts.",
            "recipes_total: \(stats.totalRecipeCount)",
            "recipes_active: \(stats.activeRecipeCount)",
            "recipes_deleted: \(stats.deletedRecipeCount)",
            "recipes_favorite: \(stats.favoriteRecipeCount)",
            "category_links: \(stats.categoryLinkCount)",
            "sync_runs: \(stats.syncRunCount)",
            renderedPaths(paths),
        ].joined(separator: "\n")
    }
}

func renderedTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}

func renderedPaths(_ paths: PantryPathReport) -> String {
    [
        "home: \(paths.home)",
        "config: \(paths.config)",
        "database: \(paths.database)",
    ].joined(separator: "\n")
}

func renderedDuration(seconds: Int) -> String {
    if seconds < 60 {
        return "\(seconds)s"
    }

    let minutes = seconds / 60
    if minutes < 60 {
        return "\(minutes)m"
    }

    let hours = minutes / 60
    if hours < 24 {
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainingMinutes)m"
    }

    let days = hours / 24
    let remainingHours = hours % 24
    return remainingHours == 0 ? "\(days)d" : "\(days)d \(remainingHours)h"
}
