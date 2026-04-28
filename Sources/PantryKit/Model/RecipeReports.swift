import Foundation

public struct RecipesListReport: ConsoleRenderable, CSVRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let derivedReadPath: String?
    public let ingredientReadPath: String?
    public let usageReadPath: String?
    public let derivedLastSuccessAt: Date?
    public let derivedFreshnessSeconds: Int?
    public let ingredientLastSuccessAt: Date?
    public let ingredientFreshnessSeconds: Int?
    public let usageLastSuccessAt: Date?
    public let usageFreshnessSeconds: Int?
    public let recipeCount: Int
    public let canonicalFilters: RecipeQueryFilters
    public let ingredientFilter: RecipeIngredientFilter
    public let derivedConstraints: RecipeDerivedConstraints
    public let sort: RecipeListSort
    public let recipes: [RecipeSummary]

    public init(
        recipes: [RecipeSummary],
        canonicalFilters: RecipeQueryFilters = RecipeQueryFilters(),
        ingredientFilter: RecipeIngredientFilter = RecipeIngredientFilter(),
        derivedConstraints: RecipeDerivedConstraints = RecipeDerivedConstraints(),
        sort: RecipeListSort = .name,
        readPath: String = "direct-source",
        derivedReadPath: String? = nil,
        ingredientReadPath: String? = nil,
        usageReadPath: String? = nil,
        derivedLastSuccessAt: Date? = nil,
        derivedFreshnessSeconds: Int? = nil,
        ingredientLastSuccessAt: Date? = nil,
        ingredientFreshnessSeconds: Int? = nil,
        usageLastSuccessAt: Date? = nil,
        usageFreshnessSeconds: Int? = nil
    ) {
        self.command = "recipes list"
        self.readPath = readPath
        self.derivedReadPath = derivedReadPath
        self.ingredientReadPath = ingredientReadPath
        self.usageReadPath = usageReadPath
        self.derivedLastSuccessAt = derivedLastSuccessAt
        self.derivedFreshnessSeconds = derivedFreshnessSeconds
        self.ingredientLastSuccessAt = ingredientLastSuccessAt
        self.ingredientFreshnessSeconds = ingredientFreshnessSeconds
        self.usageLastSuccessAt = usageLastSuccessAt
        self.usageFreshnessSeconds = usageFreshnessSeconds
        self.recipeCount = recipes.count
        self.canonicalFilters = canonicalFilters
        self.ingredientFilter = ingredientFilter
        self.derivedConstraints = derivedConstraints
        self.sort = sort
        self.recipes = recipes
    }

    public var humanDescription: String {
        var lines = ["\(command): \(recipeCount) recipes", "read_path: \(readPath)"]
        if let derivedReadPath {
            lines.append("derived_read_path: \(derivedReadPath)")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "derived_index",
                lastSuccessAt: derivedLastSuccessAt,
                freshnessSeconds: derivedFreshnessSeconds
            ))
        }
        if let ingredientReadPath {
            lines.append("ingredient_read_path: \(ingredientReadPath)")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "ingredient_index",
                lastSuccessAt: ingredientLastSuccessAt,
                freshnessSeconds: ingredientFreshnessSeconds
            ))
        }
        if let usageReadPath {
            lines.append("usage_read_path: \(usageReadPath)")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "usage_index",
                lastSuccessAt: usageLastSuccessAt,
                freshnessSeconds: usageFreshnessSeconds
            ))
        }
        lines.append(contentsOf: renderedCanonicalRecipeFilters(canonicalFilters))
        lines.append(contentsOf: renderedRecipeIngredientFilter(ingredientFilter))
        lines.append(contentsOf: renderedRecipeDerivedConstraints(derivedConstraints))
        lines.append("sort: \(sort.rawValue)")

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

            parts.append(contentsOf: renderedRecipeDerivedEvidence(recipe.derivedFeatures))
            parts.append(contentsOf: renderedRecipeUsageEvidence(recipe.usageStats))
            lines.append(parts.joined(separator: " | "))
        }

        return lines.joined(separator: "\n")
    }

    public var csvHeaders: [String] {
        recipeResultCSVHeaders
    }

    public var csvRows: [[String]] {
        recipes.map(recipeCSVRow)
    }
}

public struct RecipeShowReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let recipe: RecipeDetail
    public let derivedFeatures: RecipeDerivedFeatures?
    public let usageStats: RecipeUsageStats?
    public let derivedLastSuccessAt: Date?
    public let derivedFreshnessSeconds: Int?
    public let usageLastSuccessAt: Date?
    public let usageFreshnessSeconds: Int?

    public init(
        recipe: RecipeDetail,
        derivedFeatures: RecipeDerivedFeatures? = nil,
        usageStats: RecipeUsageStats? = nil,
        readPath: String = "direct-source",
        derivedLastSuccessAt: Date? = nil,
        derivedFreshnessSeconds: Int? = nil,
        usageLastSuccessAt: Date? = nil,
        usageFreshnessSeconds: Int? = nil
    ) {
        self.command = "recipes show"
        self.readPath = readPath
        self.recipe = recipe
        self.derivedFeatures = derivedFeatures
        self.usageStats = usageStats
        self.derivedLastSuccessAt = derivedLastSuccessAt
        self.derivedFreshnessSeconds = derivedFreshnessSeconds
        self.usageLastSuccessAt = usageLastSuccessAt
        self.usageFreshnessSeconds = usageFreshnessSeconds
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
        if let sourceFingerprint = recipe.sourceFingerprint, !sourceFingerprint.isEmpty {
            lines.append("source_fingerprint: \(sourceFingerprint)")
        }

        if let usageStats {
            lines.append("usage_read_path: sidecar-derived")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "usage_index",
                lastSuccessAt: usageLastSuccessAt,
                freshnessSeconds: usageFreshnessSeconds
            ))
            lines.append("usage_derived_at: \(renderedTimestamp(usageStats.derivedAt))")
            lines.append("meal_count: \(usageStats.mealCount)")
            if let firstMealAt = usageStats.firstMealAt {
                lines.append("first_meal_at: \(firstMealAt)")
            }
            if let firstCookedAt = usageStats.firstCookedAt {
                lines.append("first_cooked_at: \(firstCookedAt)")
            }
            if let lastMealAt = usageStats.lastMealAt {
                lines.append("last_meal_at: \(lastMealAt)")
            }
            if let daysSinceLastMeal = usageStats.daysSinceLastMeal() {
                lines.append("days_since_last_meal: \(daysSinceLastMeal)")
            }
            if let mealGapDays = usageStats.mealGapDays {
                lines.append("meal_gap_days: \(renderedIntArray(mealGapDays))")
            }
            if let daysSpannedByMeals = usageStats.daysSpannedByMeals {
                lines.append("days_spanned_by_meals: \(daysSpannedByMeals)")
            }
            if let medianMealGapDays = usageStats.medianMealGapDays {
                lines.append("median_meal_gap_days: \(renderedDouble(medianMealGapDays))")
            }
            if let mealShare = usageStats.mealShare {
                lines.append("meal_share: \(renderedDouble(mealShare))")
            }
        }

        if let derivedFeatures {
            lines.append("derived_read_path: sidecar-derived")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "derived_index",
                lastSuccessAt: derivedLastSuccessAt,
                freshnessSeconds: derivedFreshnessSeconds
            ))
            lines.append("derived_at: \(renderedTimestamp(derivedFeatures.derivedAt))")

            switch derivedFeatures.sourceFingerprintMatches(recipe.sourceFingerprint) {
            case .some(true):
                lines.append("derived_source_fingerprint_matches: yes")
            case .some(false):
                lines.append("derived_source_fingerprint_matches: no")
            case .none:
                lines.append("derived_source_fingerprint_matches: unknown")
            }

            if let prepTimeMinutes = derivedFeatures.prepTimeMinutes {
                lines.append("derived_prep_time_minutes: \(prepTimeMinutes)")
            }

            if let cookTimeMinutes = derivedFeatures.cookTimeMinutes {
                lines.append("derived_cook_time_minutes: \(cookTimeMinutes)")
            }

            if let totalTimeMinutes = derivedFeatures.totalTimeMinutes {
                lines.append("derived_total_time_minutes: \(totalTimeMinutes)")
            }

            if let totalTimeBasis = derivedFeatures.totalTimeBasis {
                lines.append("derived_total_time_basis: \(totalTimeBasis.rawValue)")
            }

            if let ingredientLineCount = derivedFeatures.ingredientLineCount {
                lines.append("derived_ingredient_line_count: \(ingredientLineCount)")
            }

            if let ingredientLineCountBasis = derivedFeatures.ingredientLineCountBasis {
                lines.append("derived_ingredient_line_count_basis: \(ingredientLineCountBasis.rawValue)")
            }
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
    public let capturedPaprikaSyncFreshnessSeconds: Int?
    public let recipeSearchFreshnessSeconds: Int?
    public let recipeFeatureFreshnessSeconds: Int?
    public let recipeIngredientFreshnessSeconds: Int?
    public let recipeUsageFreshnessSeconds: Int?
    public let ingredientPairFreshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(stats: PantryIndexStats, paths: PantryPaths, now: Date) {
        self.command = "index stats"
        self.stats = stats
        self.capturedPaprikaSyncFreshnessSeconds = stats.sourceState?.paprikaSync.map {
            max(0, Int(now.timeIntervalSince($0.lastSyncAt)))
        }
        self.recipeSearchFreshnessSeconds = stats.lastSuccessfulRecipeSearchRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.recipeFeatureFreshnessSeconds = stats.lastSuccessfulRecipeFeatureRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.recipeIngredientFreshnessSeconds = stats.lastSuccessfulRecipeIngredientRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.recipeUsageFreshnessSeconds = stats.lastSuccessfulRecipeUsageRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.ingredientPairFreshnessSeconds = stats.lastSuccessfulIngredientPairRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): Owned sidecar index status.",
            "source_state_captured: \(stats.sourceState == nil ? "no" : "yes")",
            "recipe_search_ready: \(stats.recipeSearchReady ? "yes" : "no")",
            "recipe_search_documents: \(stats.recipeSearchDocumentCount)",
            "recipe_features_ready: \(stats.recipeFeaturesReady ? "yes" : "no")",
            "recipe_feature_rows: \(stats.recipeFeatureCount)",
            "recipe_features_with_total_time: \(stats.recipeFeaturesWithTotalTimeCount)",
            "recipe_features_with_ingredient_line_count: \(stats.recipeFeaturesWithIngredientLineCountCount)",
            "recipe_ingredient_index_ready: \(stats.recipeIngredientIndexReady ? "yes" : "no")",
            "recipe_ingredient_recipes: \(stats.recipeIngredientRecipeCount)",
            "recipe_ingredient_lines: \(stats.recipeIngredientLineCount)",
            "recipe_ingredient_tokens: \(stats.recipeIngredientTokenCount)",
            "recipe_usage_index_ready: \(stats.recipeUsageStatsReady ? "yes" : "no")",
            "recipe_usage_stat_rows: \(stats.recipeUsageStatsCount)",
            "recipe_usage_rows_with_last_meal_at: \(stats.recipeUsageStatsWithLastMealAtCount)",
            "recipe_usage_rows_with_gap_arrays: \(stats.recipeUsageStatsWithGapArrayCount)",
            "recipe_usage_total_meals: \(stats.recipeUsageTotalMealCount)",
            "ingredient_pair_evidence_ready: \(stats.ingredientPairEvidenceReady ? "yes" : "no")",
            "ingredient_pair_summaries: \(stats.ingredientPairSummaryCount)",
            "ingredient_pair_recipe_evidence_rows: \(stats.ingredientPairRecipeEvidenceCount)",
        ]

        if let sourceState = stats.sourceState {
            lines.append("source_state_observed_at: \(renderedTimestamp(sourceState.observedAt))")
            if let sourceLocation = sourceState.sourceLocation, !sourceLocation.isEmpty {
                lines.append("source_state_source_location: \(sourceLocation)")
            }
        }

        lines.append(contentsOf: renderedCapturedPaprikaSyncLines(
            stats.sourceState?.paprikaSync,
            freshnessSeconds: capturedPaprikaSyncFreshnessSeconds
        ))

        if let lastRun = stats.lastRecipeSearchRun {
            lines.append("recipe_search_last_run_at: \(renderedTimestamp(lastRun.startedAt))")
            lines.append("recipe_search_last_run_status: \(lastRun.status.rawValue)")
        }

        if let lastSuccess = stats.lastSuccessfulRecipeSearchRun {
            lines.append("recipe_search_last_success_at: \(renderedTimestamp(lastSuccess.finishedAt ?? lastSuccess.startedAt))")
        }

        if let recipeSearchFreshnessSeconds {
            lines.append("recipe_search_freshness: \(renderedDuration(seconds: recipeSearchFreshnessSeconds)) old")
        } else {
            lines.append("recipe_search_freshness: never-built")
        }

        if let lastRun = stats.lastRecipeFeatureRun {
            lines.append("recipe_features_last_run_at: \(renderedTimestamp(lastRun.startedAt))")
            lines.append("recipe_features_last_run_status: \(lastRun.status.rawValue)")
        }

        if let lastSuccess = stats.lastSuccessfulRecipeFeatureRun {
            lines.append("recipe_features_last_success_at: \(renderedTimestamp(lastSuccess.finishedAt ?? lastSuccess.startedAt))")
        }

        if let recipeFeatureFreshnessSeconds {
            lines.append("recipe_features_freshness: \(renderedDuration(seconds: recipeFeatureFreshnessSeconds)) old")
        } else {
            lines.append("recipe_features_freshness: never-built")
        }

        if let lastRun = stats.lastRecipeIngredientRun {
            lines.append("recipe_ingredients_last_run_at: \(renderedTimestamp(lastRun.startedAt))")
            lines.append("recipe_ingredients_last_run_status: \(lastRun.status.rawValue)")
        }

        if let lastSuccess = stats.lastSuccessfulRecipeIngredientRun {
            lines.append("recipe_ingredients_last_success_at: \(renderedTimestamp(lastSuccess.finishedAt ?? lastSuccess.startedAt))")
        }

        if let recipeIngredientFreshnessSeconds {
            lines.append("recipe_ingredients_freshness: \(renderedDuration(seconds: recipeIngredientFreshnessSeconds)) old")
        } else {
            lines.append("recipe_ingredients_freshness: never-built")
        }

        if let lastRun = stats.lastRecipeUsageRun {
            lines.append("recipe_usage_last_run_at: \(renderedTimestamp(lastRun.startedAt))")
            lines.append("recipe_usage_last_run_status: \(lastRun.status.rawValue)")
        }

        if let lastSuccess = stats.lastSuccessfulRecipeUsageRun {
            lines.append("recipe_usage_last_success_at: \(renderedTimestamp(lastSuccess.finishedAt ?? lastSuccess.startedAt))")
        }

        if let recipeUsageFreshnessSeconds {
            lines.append("recipe_usage_freshness: \(renderedDuration(seconds: recipeUsageFreshnessSeconds)) old")
        } else {
            lines.append("recipe_usage_freshness: never-built")
        }

        if let lastRun = stats.lastIngredientPairRun {
            lines.append("ingredient_pairs_last_run_at: \(renderedTimestamp(lastRun.startedAt))")
            lines.append("ingredient_pairs_last_run_status: \(lastRun.status.rawValue)")
        }

        if let lastSuccess = stats.lastSuccessfulIngredientPairRun {
            lines.append("ingredient_pairs_last_success_at: \(renderedTimestamp(lastSuccess.finishedAt ?? lastSuccess.startedAt))")
        }

        if let ingredientPairFreshnessSeconds {
            lines.append("ingredient_pairs_freshness: \(renderedDuration(seconds: ingredientPairFreshnessSeconds)) old")
        } else {
            lines.append("ingredient_pairs_freshness: never-built")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct IndexRebuildReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let summary: RecipeIndexesRebuildSummary
    public let paths: PantryPathReport

    public init(command: String = "index rebuild", summary: RecipeIndexesRebuildSummary, paths: PantryPaths) {
        self.command = command
        self.summary = summary
        self.paths = paths.report
    }

    public var humanDescription: String {
        let rebuildDurationMilliseconds = max(0, Int((summary.finishedAt.timeIntervalSince(summary.startedAt) * 1_000).rounded()))
        let action = summary.refreshedIngredientPairEvidence
            ? "Rebuilt owned recipe search, feature, usage, ingredient-token, and ingredient-pair evidence indexes."
            : "Updated owned recipe search, feature, usage, and ingredient-token indexes; ingredient-pair evidence was not refreshed."
        var lines = [
            "\(command): \(action)",
            "duration_ms: \(rebuildDurationMilliseconds)",
            "recipe_search_documents: \(summary.recipeSearchDocumentCount)",
            "recipe_feature_rows: \(summary.recipeFeatureCount)",
            "recipe_features_with_total_time: \(summary.recipeFeaturesWithTotalTimeCount)",
            "recipe_features_with_ingredient_line_count: \(summary.recipeFeaturesWithIngredientLineCountCount)",
            "recipe_ingredient_recipes: \(summary.recipeIngredientRecipeCount)",
            "recipe_ingredient_lines: \(summary.recipeIngredientLineCount)",
            "recipe_ingredient_tokens: \(summary.recipeIngredientTokenCount)",
            "recipe_usage_stat_rows: \(summary.recipeUsageStatsCount)",
            "recipe_usage_rows_with_last_meal_at: \(summary.recipeUsageStatsWithLastMealAtCount)",
            "recipe_usage_rows_with_gap_arrays: \(summary.recipeUsageStatsWithGapArrayCount)",
            "linked_meals_with_recipe_uid: \(summary.linkedMealCount)",
            "total_qualifying_meals: \(summary.totalMealCount)",
        ]

        if summary.refreshedIngredientPairEvidence {
            lines.append("ingredient_pair_evidence_refreshed: yes")
            lines.append("ingredient_pair_summaries: \(summary.ingredientPairSummaryCount)")
            lines.append("ingredient_pair_recipe_evidence_rows: \(summary.ingredientPairRecipeEvidenceCount)")
        } else {
            lines.append("ingredient_pair_evidence_refreshed: no")
            lines.append("ingredient_pair_evidence_note: skipped by `index update`; run `paprika-pantry index rebuild` to refresh pairings")
        }

        if let sourceState = summary.sourceState {
            lines.append("source_state_observed_at: \(renderedTimestamp(sourceState.observedAt))")
        }

        lines.append(contentsOf: renderedCapturedPaprikaSyncLines(summary.sourceState?.paprikaSync))
        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct RecipesSearchReport: ConsoleRenderable, CSVRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let derivedReadPath: String?
    public let ingredientReadPath: String?
    public let usageReadPath: String?
    public let searchLastSuccessAt: Date?
    public let searchFreshnessSeconds: Int?
    public let derivedLastSuccessAt: Date?
    public let derivedFreshnessSeconds: Int?
    public let ingredientLastSuccessAt: Date?
    public let ingredientFreshnessSeconds: Int?
    public let usageLastSuccessAt: Date?
    public let usageFreshnessSeconds: Int?
    public let query: String
    public let resultCount: Int
    public let canonicalFilters: RecipeQueryFilters
    public let ingredientFilter: RecipeIngredientFilter
    public let derivedConstraints: RecipeDerivedConstraints
    public let sort: RecipeSearchSort
    public let results: [IndexedRecipeSearchResult]
    public let paths: PantryPathReport

    public init(
        query: String,
        canonicalFilters: RecipeQueryFilters = RecipeQueryFilters(),
        ingredientFilter: RecipeIngredientFilter = RecipeIngredientFilter(),
        derivedConstraints: RecipeDerivedConstraints = RecipeDerivedConstraints(),
        sort: RecipeSearchSort = .relevance,
        results: [IndexedRecipeSearchResult],
        paths: PantryPaths,
        readPath: String = "sidecar-search-index",
        derivedReadPath: String? = nil,
        ingredientReadPath: String? = nil,
        usageReadPath: String? = nil,
        searchLastSuccessAt: Date? = nil,
        searchFreshnessSeconds: Int? = nil,
        derivedLastSuccessAt: Date? = nil,
        derivedFreshnessSeconds: Int? = nil,
        ingredientLastSuccessAt: Date? = nil,
        ingredientFreshnessSeconds: Int? = nil,
        usageLastSuccessAt: Date? = nil,
        usageFreshnessSeconds: Int? = nil
    ) {
        self.command = "recipes search"
        self.readPath = readPath
        self.derivedReadPath = derivedReadPath
        self.ingredientReadPath = ingredientReadPath
        self.usageReadPath = usageReadPath
        self.searchLastSuccessAt = searchLastSuccessAt
        self.searchFreshnessSeconds = searchFreshnessSeconds
        self.derivedLastSuccessAt = derivedLastSuccessAt
        self.derivedFreshnessSeconds = derivedFreshnessSeconds
        self.ingredientLastSuccessAt = ingredientLastSuccessAt
        self.ingredientFreshnessSeconds = ingredientFreshnessSeconds
        self.usageLastSuccessAt = usageLastSuccessAt
        self.usageFreshnessSeconds = usageFreshnessSeconds
        self.query = query
        self.resultCount = results.count
        self.canonicalFilters = canonicalFilters
        self.ingredientFilter = ingredientFilter
        self.derivedConstraints = derivedConstraints
        self.sort = sort
        self.results = results
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(resultCount) matches",
            "read_path: \(readPath)",
            "query: \(query)",
        ]
        lines.append(contentsOf: renderedIndexFreshnessLines(
            prefix: "search_index",
            lastSuccessAt: searchLastSuccessAt,
            freshnessSeconds: searchFreshnessSeconds
        ))
        if let derivedReadPath {
            lines.append("derived_read_path: \(derivedReadPath)")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "derived_index",
                lastSuccessAt: derivedLastSuccessAt,
                freshnessSeconds: derivedFreshnessSeconds
            ))
        }
        if let ingredientReadPath {
            lines.append("ingredient_read_path: \(ingredientReadPath)")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "ingredient_index",
                lastSuccessAt: ingredientLastSuccessAt,
                freshnessSeconds: ingredientFreshnessSeconds
            ))
        }
        if let usageReadPath {
            lines.append("usage_read_path: \(usageReadPath)")
            lines.append(contentsOf: renderedIndexFreshnessLines(
                prefix: "usage_index",
                lastSuccessAt: usageLastSuccessAt,
                freshnessSeconds: usageFreshnessSeconds
            ))
        }
        lines.append(contentsOf: renderedCanonicalRecipeFilters(canonicalFilters))
        lines.append(contentsOf: renderedRecipeIngredientFilter(ingredientFilter))
        lines.append(contentsOf: renderedRecipeDerivedConstraints(derivedConstraints))
        lines.append("sort: \(sort.rawValue)")

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

            parts.append(contentsOf: renderedRecipeDerivedEvidence(recipe.derivedFeatures))
            parts.append(contentsOf: renderedRecipeUsageEvidence(recipe.usageStats))
            lines.append(parts.joined(separator: " | "))
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }

    public var csvHeaders: [String] {
        ["query"] + recipeResultCSVHeaders
    }

    public var csvRows: [[String]] {
        results.map { [query] + recipeCSVRow(for: $0) }
    }
}

public struct RecipesPairingsReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let basis: String
    public let token: String?
    public let withToken: String?
    public let minRecipes: Int
    public let limit: Int
    public let evidenceLimit: Int
    public let sort: IngredientPairEvidenceSort
    public let resultCount: Int
    public let results: [IngredientPairEvidenceSummary]
    public let ingredientPairLastSuccessAt: Date?
    public let routineIndexLastSuccessAt: Date?
    public let ingredientPairFreshnessSeconds: Int?
    public let ingredientPairEvidenceMayBeStale: Bool
    public let paths: PantryPathReport

    public init(
        results: [IngredientPairEvidenceSummary],
        token: String? = nil,
        withToken: String? = nil,
        minRecipes: Int = 1,
        limit: Int = 20,
        evidenceLimit: Int = 3,
        sort: IngredientPairEvidenceSort = .recipes,
        paths: PantryPaths,
        readPath: String = "sidecar-ingredient-pair-index",
        basis: String = PantrySidecarStore.ingredientPairEvidenceBasis,
        ingredientPairLastSuccessAt: Date? = nil,
        routineIndexLastSuccessAt: Date? = nil,
        ingredientPairFreshnessSeconds: Int? = nil
    ) {
        self.command = "recipes pairings"
        self.readPath = readPath
        self.basis = basis
        self.token = token
        self.withToken = withToken
        self.minRecipes = minRecipes
        self.limit = limit
        self.evidenceLimit = evidenceLimit
        self.sort = sort
        self.resultCount = results.count
        self.results = results
        self.ingredientPairLastSuccessAt = ingredientPairLastSuccessAt
        self.routineIndexLastSuccessAt = routineIndexLastSuccessAt
        self.ingredientPairFreshnessSeconds = ingredientPairFreshnessSeconds
        self.ingredientPairEvidenceMayBeStale = ingredientPairLastSuccessAt.map { pairDate in
            routineIndexLastSuccessAt.map { pairDate < $0 } ?? false
        } ?? false
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(resultCount) token pairs",
            "read_path: \(readPath)",
            "basis: \(basis)",
        ]
        lines.append(contentsOf: renderedIndexFreshnessLines(
            prefix: "ingredient_pair_index",
            lastSuccessAt: ingredientPairLastSuccessAt,
            freshnessSeconds: ingredientPairFreshnessSeconds
        ))
        if let routineIndexLastSuccessAt {
            lines.append("routine_index_last_success_at: \(renderedTimestamp(routineIndexLastSuccessAt))")
        }
        if ingredientPairEvidenceMayBeStale {
            lines.append("ingredient_pair_evidence_may_be_stale: yes")
            lines.append("ingredient_pair_evidence_note: pairings were built before the latest routine index update; run `paprika-pantry index rebuild` to refresh pairings")
        } else {
            lines.append("ingredient_pair_evidence_may_be_stale: no")
        }

        if let token {
            lines.append("token: \(token)")
        }

        if let withToken {
            lines.append("with_token: \(withToken)")
        }

        lines.append("min_recipes: \(minRecipes)")
        lines.append("sort: \(sort.rawValue)")
        lines.append("limit: \(limit)")
        lines.append("evidence_limit: \(evidenceLimit)")

        if results.isEmpty {
            lines.append("No ingredient token pairs matched in the built pairing index.")
            if ingredientPairEvidenceMayBeStale {
                lines.append("If this should exist after recent source changes, run `paprika-pantry index rebuild` to refresh pairings.")
            }
            lines.append(renderedPaths(paths))
            return lines.joined(separator: "\n")
        }

        for result in results {
            var parts = [
                "\(result.tokenA) + \(result.tokenB)",
                "recipes=\(result.recipeCount)",
                "cooked_recipes=\(result.cookedRecipeCount)",
                "meals=\(result.cookedMealCount)",
                "favorites=\(result.favoriteRecipeCount)",
                "rated=\(result.ratedRecipeCount)",
            ]

            if let averageStarRating = result.averageStarRating {
                parts.append("avg_rating=\(String(format: "%.2f", averageStarRating))")
            } else {
                parts.append("avg_rating=unrated")
            }

            if let firstMealAt = result.firstMealAt {
                parts.append("first_meal=\(firstMealAt)")
            }

            if let lastMealAt = result.lastMealAt {
                parts.append("last_meal=\(lastMealAt)")
            }

            lines.append(parts.joined(separator: " | "))

            for evidence in result.recipeEvidence {
                var evidenceParts = [
                    "  evidence: \(evidence.recipeUID)  \(evidence.recipeName)",
                    "\(result.tokenA)_lines=\(renderedLineNumbers(evidence.tokenALineNumbers))",
                    "\(result.tokenB)_lines=\(renderedLineNumbers(evidence.tokenBLineNumbers))",
                ]

                if let sourceName = evidence.sourceName, !sourceName.isEmpty {
                    evidenceParts.append("source=\(sourceName)")
                }

                if let starRating = evidence.starRating {
                    evidenceParts.append("rating=\(starRating)")
                }

                if evidence.isFavorite {
                    evidenceParts.append("favorite=yes")
                }

                evidenceParts.append("meals=\(evidence.mealCount)")

                if let lastMealAt = evidence.lastMealAt {
                    evidenceParts.append("last_meal=\(lastMealAt)")
                }

                lines.append(evidenceParts.joined(separator: " | "))
            }
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct RecipeFeaturesReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let sourceReadPath: String
    public let derivedReadPath: String
    public let recipe: RecipeDetail
    public let features: RecipeDerivedFeatures
    public let derivedLastSuccessAt: Date?
    public let derivedFreshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(
        recipe: RecipeDetail,
        features: RecipeDerivedFeatures,
        paths: PantryPaths,
        sourceReadPath: String = "direct-source",
        derivedReadPath: String = "sidecar-derived",
        derivedLastSuccessAt: Date? = nil,
        derivedFreshnessSeconds: Int? = nil
    ) {
        self.command = "recipes features"
        self.sourceReadPath = sourceReadPath
        self.derivedReadPath = derivedReadPath
        self.recipe = recipe
        self.features = features
        self.derivedLastSuccessAt = derivedLastSuccessAt
        self.derivedFreshnessSeconds = derivedFreshnessSeconds
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(recipe.name)",
            "source_read_path: \(sourceReadPath)",
            "derived_read_path: \(derivedReadPath)",
            "uid: \(recipe.uid)",
        ]
        lines.append(contentsOf: renderedIndexFreshnessLines(
            prefix: "derived_index",
            lastSuccessAt: derivedLastSuccessAt,
            freshnessSeconds: derivedFreshnessSeconds
        ))

        if !recipe.categories.isEmpty {
            lines.append("categories: \(recipe.categories.joined(separator: ", "))")
        }

        if let sourceName = recipe.sourceName, !sourceName.isEmpty {
            lines.append("source_name: \(sourceName)")
        }

        if let prepTime = recipe.prepTime, !prepTime.isEmpty {
            lines.append("source_prep_time: \(prepTime)")
        }

        if let cookTime = recipe.cookTime, !cookTime.isEmpty {
            lines.append("source_cook_time: \(cookTime)")
        }

        if let totalTime = recipe.totalTime, !totalTime.isEmpty {
            lines.append("source_total_time: \(totalTime)")
        }

        lines.append("derived_at: \(renderedTimestamp(features.derivedAt))")

        switch features.sourceFingerprintMatches(recipe.sourceFingerprint) {
        case .some(true):
            lines.append("derived_source_fingerprint_matches: yes")
        case .some(false):
            lines.append("derived_source_fingerprint_matches: no")
        case .none:
            lines.append("derived_source_fingerprint_matches: unknown")
        }

        if let prepTimeMinutes = features.prepTimeMinutes {
            lines.append("prep_time_minutes: \(prepTimeMinutes)")
        }

        if let cookTimeMinutes = features.cookTimeMinutes {
            lines.append("cook_time_minutes: \(cookTimeMinutes)")
        }

        if let totalTimeMinutes = features.totalTimeMinutes {
            lines.append("total_time_minutes: \(totalTimeMinutes)")
        }

        if let totalTimeBasis = features.totalTimeBasis {
            lines.append("total_time_basis: \(totalTimeBasis.rawValue)")
        }

        if let ingredientLineCount = features.ingredientLineCount {
            lines.append("ingredient_line_count: \(ingredientLineCount)")
        }

        if let ingredientLineCountBasis = features.ingredientLineCountBasis {
            lines.append("ingredient_line_count_basis: \(ingredientLineCountBasis.rawValue)")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct RecipeIngredientsReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let sourceReadPath: String
    public let ingredientReadPath: String
    public let recipe: RecipeDetail
    public let ingredientIndex: RecipeIngredientIndex?
    public let ingredientLastSuccessAt: Date?
    public let ingredientFreshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(
        recipe: RecipeDetail,
        ingredientIndex: RecipeIngredientIndex?,
        paths: PantryPaths,
        sourceReadPath: String = "direct-source",
        ingredientReadPath: String = "sidecar-ingredient-index",
        ingredientLastSuccessAt: Date? = nil,
        ingredientFreshnessSeconds: Int? = nil
    ) {
        self.command = "recipes ingredients"
        self.sourceReadPath = sourceReadPath
        self.ingredientReadPath = ingredientReadPath
        self.recipe = recipe
        self.ingredientIndex = ingredientIndex
        self.ingredientLastSuccessAt = ingredientLastSuccessAt
        self.ingredientFreshnessSeconds = ingredientFreshnessSeconds
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(recipe.name)",
            "source_read_path: \(sourceReadPath)",
            "ingredient_read_path: \(ingredientReadPath)",
            "uid: \(recipe.uid)",
        ]
        lines.append(contentsOf: renderedIndexFreshnessLines(
            prefix: "ingredient_index",
            lastSuccessAt: ingredientLastSuccessAt,
            freshnessSeconds: ingredientFreshnessSeconds
        ))

        if !recipe.categories.isEmpty {
            lines.append("categories: \(recipe.categories.joined(separator: ", "))")
        }

        if let sourceName = recipe.sourceName, !sourceName.isEmpty {
            lines.append("source_name: \(sourceName)")
        }

        if let ingredientIndex {
            lines.append("derived_at: \(renderedTimestamp(ingredientIndex.derivedAt))")

            switch ingredientIndex.sourceFingerprintMatches(recipe.sourceFingerprint) {
            case .some(true):
                lines.append("derived_source_fingerprint_matches: yes")
            case .some(false):
                lines.append("derived_source_fingerprint_matches: no")
            case .none:
                lines.append("derived_source_fingerprint_matches: unknown")
            }

            lines.append("indexed_ingredient_lines: \(ingredientIndex.lines.count)")
            lines.append("indexed_ingredient_tokens: \(ingredientIndex.normalizedTokenCount)")
        } else {
            lines.append("indexed_ingredient_lines: 0")
            lines.append("indexed_ingredient_tokens: 0")
        }

        if let ingredients = recipe.ingredients, !ingredients.isEmpty {
            lines.append("source_ingredients:")
            lines.append(ingredients)
        }

        if let ingredientIndex, !ingredientIndex.lines.isEmpty {
            lines.append("indexed_lines:")
            for line in ingredientIndex.lines {
                let normalizedTokens = line.normalizedTokens.isEmpty ? "-" : line.normalizedTokens.joined(separator: ", ")
                let normalizedText = line.normalizedText ?? "-"
                lines.append(
                    "\(line.lineNumber): source=\"\(line.sourceText)\" | normalized_text=\(normalizedText) | normalized_tokens=\(normalizedTokens)"
                )
            }
        } else {
            lines.append("No non-empty ingredient lines were indexed from the source recipe.")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

func renderedTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = false
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

func renderedIndexFreshnessLines(prefix: String, lastSuccessAt: Date?, freshnessSeconds: Int?) -> [String] {
    var lines = [String]()

    if let lastSuccessAt {
        lines.append("\(prefix)_last_success_at: \(renderedTimestamp(lastSuccessAt))")
    }

    if let freshnessSeconds {
        lines.append("\(prefix)_freshness: \(renderedDuration(seconds: freshnessSeconds)) old")
    }

    return lines
}

func renderedLineNumbers(_ lineNumbers: [Int]) -> String {
    lineNumbers.isEmpty ? "-" : lineNumbers.map(String.init).joined(separator: ",")
}

func renderedCanonicalRecipeFilters(_ filters: RecipeQueryFilters) -> [String] {
    var lines = [String]()

    if filters.favoritesOnly {
        lines.append("canonical.favorite_only: yes")
    }

    if let minRating = filters.minRating {
        lines.append("canonical.min_rating: \(minRating)")
    }

    if let maxRating = filters.maxRating {
        lines.append("canonical.max_rating: \(maxRating)")
    }

    if !filters.categoryNames.isEmpty {
        lines.append("canonical.categories_all: \(filters.categoryNames.joined(separator: ", "))")
    }

    return lines
}

func renderedCapturedPaprikaSyncLines(
    _ sync: PaprikaSyncDetails?,
    freshnessSeconds: Int? = nil
) -> [String] {
    guard let sync else {
        return [
            "captured_paprika_sync_freshness: unavailable",
        ]
    }

    var lines = [
        "captured_paprika_last_sync_at: \(renderedTimestamp(sync.lastSyncAt))",
        "captured_paprika_sync_signal_source: \(sync.signalSource)",
        "captured_paprika_sync_signal_location: \(sync.signalLocation)",
    ]

    if let freshnessSeconds {
        lines.append("captured_paprika_sync_freshness: \(renderedDuration(seconds: freshnessSeconds)) old")
    }

    return lines
}

func renderedRecipeDerivedConstraints(_ constraints: RecipeDerivedConstraints) -> [String] {
    var lines = [String]()

    if let minTotalTimeMinutes = constraints.minTotalTimeMinutes {
        lines.append("derived.min_total_time_minutes: \(minTotalTimeMinutes)")
    }

    if let maxTotalTimeMinutes = constraints.maxTotalTimeMinutes {
        lines.append("derived.max_total_time_minutes: \(maxTotalTimeMinutes)")
    }

    if let minIngredientLineCount = constraints.minIngredientLineCount {
        lines.append("derived.min_ingredient_line_count: \(minIngredientLineCount)")
    }

    if let maxIngredientLineCount = constraints.maxIngredientLineCount {
        lines.append("derived.max_ingredient_line_count: \(maxIngredientLineCount)")
    }

    return lines
}

func renderedRecipeIngredientFilter(_ filter: RecipeIngredientFilter) -> [String] {
    guard !filter.isDefault else {
        return []
    }

    var lines = [String]()
    if !filter.includeTerms.isEmpty {
        lines.append("ingredient.include_terms_\(filter.includeMode.rawValue): \(filter.rawTerms.joined(separator: ", "))")
        lines.append(
            "ingredient.include_term_tokens_\(filter.includeMode.rawValue): \(renderedIngredientQueryTerms(filter.includeTerms))"
        )
    }

    if !filter.excludeTerms.isEmpty {
        lines.append("ingredient.exclude_terms_any: \(filter.excludedRawTerms.joined(separator: ", "))")
        lines.append("ingredient.exclude_term_tokens_any: \(renderedIngredientQueryTerms(filter.excludeTerms))")
    }

    return lines
}

private func renderedIngredientQueryTerms(_ terms: [RecipeIngredientQueryTerm]) -> String {
    terms.map { term in
        let renderedTokens = term.normalizedTokens.isEmpty
            ? "(no queryable tokens)"
            : term.normalizedTokens.joined(separator: ", ")
        return "\(term.rawTerm)=\(renderedTokens)"
    }
    .joined(separator: "; ")
}

func renderedRecipeDerivedEvidence(_ features: RecipeDerivedFeatures?) -> [String] {
    guard let features else {
        return []
    }

    var parts = [String]()

    if let totalTimeMinutes = features.totalTimeMinutes {
        parts.append("derived_total_time_minutes=\(totalTimeMinutes)")
    }

    if let totalTimeBasis = features.totalTimeBasis {
        parts.append("derived_total_time_basis=\(totalTimeBasis.rawValue)")
    }

    if let ingredientLineCount = features.ingredientLineCount {
        parts.append("derived_ingredient_line_count=\(ingredientLineCount)")
    }

    if let ingredientLineCountBasis = features.ingredientLineCountBasis {
        parts.append("derived_ingredient_line_count_basis=\(ingredientLineCountBasis.rawValue)")
    }

    return parts
}

func renderedRecipeUsageEvidence(_ usageStats: RecipeUsageStats?) -> [String] {
    guard let usageStats else {
        return []
    }

    var parts = ["meal_count=\(usageStats.mealCount)"]

    if let firstCookedAt = usageStats.firstCookedAt {
        parts.append("first_cooked_at=\(firstCookedAt)")
    }

    if let lastMealAt = usageStats.lastMealAt {
        parts.append("last_meal_at=\(lastMealAt)")
    }

    if let daysSinceLastMeal = usageStats.daysSinceLastMeal() {
        parts.append("days_since_last_meal=\(daysSinceLastMeal)")
    }

    if let daysSpannedByMeals = usageStats.daysSpannedByMeals {
        parts.append("days_spanned_by_meals=\(daysSpannedByMeals)")
    }

    if let medianMealGapDays = usageStats.medianMealGapDays {
        parts.append("median_meal_gap_days=\(renderedDouble(medianMealGapDays))")
    }

    if let mealShare = usageStats.mealShare {
        parts.append("meal_share=\(renderedDouble(mealShare))")
    }

    return parts
}

private let recipeResultCSVHeaders = [
    "uid",
    "name",
    "categories",
    "source_name",
    "star_rating",
    "is_favorite",
    "updated_at",
    "derived_total_time_minutes",
    "derived_ingredient_line_count",
    "meal_count",
    "last_meal_at",
    "days_spanned_by_meals",
    "median_meal_gap_days",
    "meal_share",
    "first_cooked_at",
]

private func recipeCSVRow(_ recipe: RecipeSummary) -> [String] {
    [
        recipe.uid,
        recipe.name,
        recipe.categories.joined(separator: " | "),
        recipe.sourceName ?? "",
        recipe.starRating.map(String.init) ?? "",
        recipe.isFavorite ? "true" : "false",
        recipe.updatedAt ?? "",
        recipe.derivedFeatures?.totalTimeMinutes.map(String.init) ?? "",
        recipe.derivedFeatures?.ingredientLineCount.map(String.init) ?? "",
        recipe.usageStats.map { String($0.mealCount) } ?? "",
        recipe.usageStats?.lastMealAt ?? "",
        recipe.usageStats?.daysSpannedByMeals.map(String.init) ?? "",
        recipe.usageStats?.medianMealGapDays.map(renderedDouble) ?? "",
        recipe.usageStats?.mealShare.map(renderedDouble) ?? "",
        recipe.usageStats?.firstCookedAt ?? "",
    ]
}

private func recipeCSVRow(for result: IndexedRecipeSearchResult) -> [String] {
    [
        result.uid,
        result.name,
        result.categories.joined(separator: " | "),
        result.sourceName ?? "",
        result.starRating.map(String.init) ?? "",
        result.isFavorite ? "true" : "false",
        "",
        result.derivedFeatures?.totalTimeMinutes.map(String.init) ?? "",
        result.derivedFeatures?.ingredientLineCount.map(String.init) ?? "",
        result.usageStats.map { String($0.mealCount) } ?? "",
        result.usageStats?.lastMealAt ?? "",
        result.usageStats?.daysSpannedByMeals.map(String.init) ?? "",
        result.usageStats?.medianMealGapDays.map(renderedDouble) ?? "",
        result.usageStats?.mealShare.map(renderedDouble) ?? "",
    ]
}

private func renderedIntArray(_ values: [Int]) -> String {
    "[\(values.map(String.init).joined(separator: ", "))]"
}

private func renderedDouble(_ value: Double) -> String {
    if value.rounded() == value {
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    return String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
}
