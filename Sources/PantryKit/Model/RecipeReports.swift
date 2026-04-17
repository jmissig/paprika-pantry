import Foundation

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

public struct IndexStatsReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let stats: PantryIndexStats
    public let freshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(stats: PantryIndexStats, paths: PantryPaths, now: Date) {
        self.command = "index stats"
        self.stats = stats
        self.freshnessSeconds = stats.lastSuccessfulRecipeSearchRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): Owned sidecar index status.",
            "recipe_search_ready: \(stats.recipeSearchReady ? "yes" : "no")",
            "recipe_search_documents: \(stats.recipeSearchDocumentCount)",
        ]

        if let lastRun = stats.lastRecipeSearchRun {
            lines.append("recipe_search_last_run_at: \(renderedTimestamp(lastRun.startedAt))")
            lines.append("recipe_search_last_run_status: \(lastRun.status.rawValue)")
        }

        if let lastSuccess = stats.lastSuccessfulRecipeSearchRun {
            lines.append("recipe_search_last_success_at: \(renderedTimestamp(lastSuccess.finishedAt ?? lastSuccess.startedAt))")
        }

        if let freshnessSeconds {
            lines.append("recipe_search_freshness: \(renderedDuration(seconds: freshnessSeconds)) old")
        } else {
            lines.append("recipe_search_freshness: never-built")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct IndexRebuildReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let summary: RecipeSearchIndexRebuildSummary
    public let paths: PantryPathReport

    public init(summary: RecipeSearchIndexRebuildSummary, paths: PantryPaths) {
        self.command = "index rebuild"
        self.summary = summary
        self.paths = paths.report
    }

    public var humanDescription: String {
        [
            "\(command): Rebuilt the recipe search index.",
            "started_at: \(renderedTimestamp(summary.startedAt))",
            "finished_at: \(renderedTimestamp(summary.finishedAt))",
            "recipe_count: \(summary.recipeCount)",
            renderedPaths(paths),
        ].joined(separator: "\n")
    }
}

public struct RecipesSearchReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let query: String
    public let resultCount: Int
    public let results: [IndexedRecipeSearchResult]
    public let paths: PantryPathReport

    public init(query: String, results: [IndexedRecipeSearchResult], paths: PantryPaths) {
        self.command = "recipes search"
        self.query = query
        self.resultCount = results.count
        self.results = results
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(resultCount) matches",
            "query: \(query)",
        ]

        if results.isEmpty {
            lines.append("No indexed recipes matched.")
            lines.append(renderedPaths(paths))
            return lines.joined(separator: "\n")
        }

        for recipe in results {
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

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
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
