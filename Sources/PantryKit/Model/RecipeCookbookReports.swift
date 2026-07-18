import Foundation

public struct RecipesCookbooksReport: ConsoleRenderable, CSVRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let resultCount: Int
    public let sort: CookbookAggregateSort
    public let limit: Int
    public let minRecipeCount: Int
    public let minRatedRecipeCount: Int
    public let recipeSearchLastSuccessAt: Date?
    public let recipeSearchFreshnessSeconds: Int?
    public let recipeUsageLastSuccessAt: Date?
    public let recipeUsageFreshnessSeconds: Int?
    public let aggregates: [CookbookAggregateSummary]
    public let paths: PantryPathReport

    public init(
        aggregates: [CookbookAggregateSummary],
        sort: CookbookAggregateSort,
        limit: Int,
        minRecipeCount: Int,
        minRatedRecipeCount: Int,
        indexStats: PantryIndexStats,
        paths: PantryPaths,
        now: Date,
        readPath: String = "sidecar-search-index"
    ) {
        self.command = "recipes cookbooks"
        self.readPath = readPath
        self.resultCount = aggregates.count
        self.sort = sort
        self.limit = limit
        self.minRecipeCount = minRecipeCount
        self.minRatedRecipeCount = minRatedRecipeCount
        self.recipeSearchLastSuccessAt = indexStats.lastSuccessfulRecipeSearchRun?.finishedAt ?? indexStats.lastSuccessfulRecipeSearchRun?.startedAt
        self.recipeSearchFreshnessSeconds = recipeSearchLastSuccessAt.map {
            max(0, Int(now.timeIntervalSince($0)))
        }
        self.recipeUsageLastSuccessAt = indexStats.lastSuccessfulRecipeUsageRun?.finishedAt ?? indexStats.lastSuccessfulRecipeUsageRun?.startedAt
        self.recipeUsageFreshnessSeconds = recipeUsageLastSuccessAt.map {
            max(0, Int(now.timeIntervalSince($0)))
        }
        self.aggregates = aggregates
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(resultCount) cookbook/source groups",
            "read_path: \(readPath)",
            "sort: \(sort.rawValue)",
            "min_recipes: \(minRecipeCount)",
            "min_rated_recipes: \(minRatedRecipeCount)",
            "limit: \(limit)",
        ]

        if let recipeSearchLastSuccessAt {
            lines.append("recipe_search_last_success_at: \(renderedTimestamp(recipeSearchLastSuccessAt))")
        }

        if let recipeSearchFreshnessSeconds {
            lines.append("recipe_search_freshness: \(renderedDuration(seconds: recipeSearchFreshnessSeconds)) old")
        } else {
            lines.append("recipe_search_freshness: never-built")
        }

        if let recipeUsageLastSuccessAt {
            lines.append("recipe_usage_last_success_at: \(renderedTimestamp(recipeUsageLastSuccessAt))")
        }

        if let recipeUsageFreshnessSeconds {
            lines.append("recipe_usage_freshness: \(renderedDuration(seconds: recipeUsageFreshnessSeconds)) old")
        } else {
            lines.append("recipe_usage_freshness: never-built")
        }

        if aggregates.isEmpty {
            lines.append("No cookbook/source groups matched.")
            lines.append(renderedPaths(paths))
            return lines.joined(separator: "\n")
        }

        for aggregate in aggregates {
            var parts = [renderedCookbookName(aggregate)]
            parts.append("target=\(renderedTargetHandle(aggregate.target))")
            parts.append("recipes=\(aggregate.recipeCount)")
            parts.append("rated=\(aggregate.ratedRecipeCount)")
            parts.append("unrated=\(aggregate.unratedRecipeCount)")
            parts.append("favorites=\(aggregate.favoriteRecipeCount)")
            parts.append("used_recipes=\(aggregate.usedRecipeCount)")
            parts.append("unused_recipes=\(aggregate.unusedRecipeCount)")
            parts.append("meals=\(aggregate.mealCount)")
            parts.append("meal_share=\(renderedDecimal(aggregate.mealShare))")

            if let firstMealAt = aggregate.firstMealAt {
                parts.append("first_meal=\(firstMealAt)")
            }

            if let firstCookedAt = aggregate.firstCookedAt {
                parts.append("first_cooked_at=\(firstCookedAt)")
            }

            if let lastMealAt = aggregate.lastMealAt {
                parts.append("last_meal=\(lastMealAt)")
            }

            if let averageStarRating = aggregate.averageStarRating {
                parts.append("avg_rating=\(renderedDecimal(averageStarRating))")
            } else {
                parts.append("avg_rating=unrated")
            }

            let ratings = renderedRatingDistribution(aggregate.ratingDistribution)
            if !ratings.isEmpty {
                parts.append("ratings=\(ratings)")
            }

            if aggregate.isUnlabeled {
                parts.append("is_unlabeled=yes")
            }

            lines.append(parts.joined(separator: " | "))
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }

    public var csvHeaders: [String] {
        [
            "source_name",
            "is_unlabeled",
            "recipe_count",
            "rated_recipe_count",
            "unrated_recipe_count",
            "favorite_recipe_count",
            "used_recipe_count",
            "unused_recipe_count",
            "meal_count",
            "meal_share",
            "first_meal_at",
            "last_meal_at",
            "average_star_rating",
            "rated_recipe_share",
            "favorite_recipe_share",
            "five_star_count",
            "four_star_count",
            "three_star_count",
            "two_star_count",
            "one_star_count",
            "first_cooked_at",
        ]
    }

    public var csvRows: [[String]] {
        aggregates.map { aggregate in
            [
                renderedCookbookName(aggregate),
                aggregate.isUnlabeled ? "true" : "false",
                String(aggregate.recipeCount),
                String(aggregate.ratedRecipeCount),
                String(aggregate.unratedRecipeCount),
                String(aggregate.favoriteRecipeCount),
                String(aggregate.usedRecipeCount),
                String(aggregate.unusedRecipeCount),
                String(aggregate.mealCount),
                renderedDecimal(aggregate.mealShare),
                aggregate.firstMealAt ?? "",
                aggregate.lastMealAt ?? "",
                aggregate.averageStarRating.map(renderedDecimal) ?? "",
                renderedDecimal(aggregate.ratedRecipeShare),
                renderedDecimal(aggregate.favoriteRecipeShare),
                String(aggregate.ratingDistribution.fiveStarCount),
                String(aggregate.ratingDistribution.fourStarCount),
                String(aggregate.ratingDistribution.threeStarCount),
                String(aggregate.ratingDistribution.twoStarCount),
                String(aggregate.ratingDistribution.oneStarCount),
                aggregate.firstCookedAt ?? "",
            ]
        }
    }
}


func renderedCookbookName(_ aggregate: CookbookAggregateSummary) -> String {
    if let sourceName = aggregate.sourceName, !sourceName.isEmpty {
        return sourceName
    }

    return "(unlabeled source/cookbook)"
}

func renderedRatingDistribution(_ distribution: CookbookRatingDistribution) -> String {
    let parts = [
        (5, distribution.fiveStarCount),
        (4, distribution.fourStarCount),
        (3, distribution.threeStarCount),
        (2, distribution.twoStarCount),
        (1, distribution.oneStarCount),
    ]
        .filter { $0.1 > 0 }
        .map { "\($0.0):\($0.1)" }

    return parts.joined(separator: ",")
}

func renderedDecimal(_ value: Double) -> String {
    String(format: "%.2f", value)
}
