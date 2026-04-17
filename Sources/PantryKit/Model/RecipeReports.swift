import Foundation

public struct RecipesListReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let derivedReadPath: String?
    public let ingredientReadPath: String?
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
        ingredientReadPath: String? = nil
    ) {
        self.command = "recipes list"
        self.readPath = readPath
        self.derivedReadPath = derivedReadPath
        self.ingredientReadPath = ingredientReadPath
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
        }
        if let ingredientReadPath {
            lines.append("ingredient_read_path: \(ingredientReadPath)")
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
            lines.append(parts.joined(separator: " | "))
        }

        return lines.joined(separator: "\n")
    }
}

public struct RecipeShowReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let recipe: RecipeDetail
    public let derivedFeatures: RecipeDerivedFeatures?

    public init(
        recipe: RecipeDetail,
        derivedFeatures: RecipeDerivedFeatures? = nil,
        readPath: String = "direct-source"
    ) {
        self.command = "recipes show"
        self.readPath = readPath
        self.recipe = recipe
        self.derivedFeatures = derivedFeatures
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

        if let derivedFeatures {
            lines.append("derived_read_path: sidecar-derived")
            lines.append("derived_at: \(renderedTimestamp(derivedFeatures.derivedAt))")

            switch derivedFeatures.sourceHashMatches(recipe.remoteHash) {
            case .some(true):
                lines.append("derived_source_hash_matches: yes")
            case .some(false):
                lines.append("derived_source_hash_matches: no")
            case .none:
                lines.append("derived_source_hash_matches: unknown")
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
    public let recipeSearchFreshnessSeconds: Int?
    public let recipeFeatureFreshnessSeconds: Int?
    public let recipeIngredientFreshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(stats: PantryIndexStats, paths: PantryPaths, now: Date) {
        self.command = "index stats"
        self.stats = stats
        self.recipeSearchFreshnessSeconds = stats.lastSuccessfulRecipeSearchRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.recipeFeatureFreshnessSeconds = stats.lastSuccessfulRecipeFeatureRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.recipeIngredientFreshnessSeconds = stats.lastSuccessfulRecipeIngredientRun.map {
            max(0, Int(now.timeIntervalSince($0.finishedAt ?? $0.startedAt)))
        }
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): Owned sidecar index status.",
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
        ]

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

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct IndexRebuildReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let summary: RecipeIndexesRebuildSummary
    public let paths: PantryPathReport

    public init(summary: RecipeIndexesRebuildSummary, paths: PantryPaths) {
        self.command = "index rebuild"
        self.summary = summary
        self.paths = paths.report
    }

    public var humanDescription: String {
        [
            "\(command): Rebuilt owned recipe search, feature, and ingredient indexes.",
            "started_at: \(renderedTimestamp(summary.startedAt))",
            "finished_at: \(renderedTimestamp(summary.finishedAt))",
            "recipe_search_documents: \(summary.recipeSearchDocumentCount)",
            "recipe_feature_rows: \(summary.recipeFeatureCount)",
            "recipe_features_with_total_time: \(summary.recipeFeaturesWithTotalTimeCount)",
            "recipe_features_with_ingredient_line_count: \(summary.recipeFeaturesWithIngredientLineCountCount)",
            "recipe_ingredient_recipes: \(summary.recipeIngredientRecipeCount)",
            "recipe_ingredient_lines: \(summary.recipeIngredientLineCount)",
            "recipe_ingredient_tokens: \(summary.recipeIngredientTokenCount)",
            renderedPaths(paths),
        ].joined(separator: "\n")
    }
}

public struct RecipesSearchReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let readPath: String
    public let derivedReadPath: String?
    public let ingredientReadPath: String?
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
        ingredientReadPath: String? = nil
    ) {
        self.command = "recipes search"
        self.readPath = readPath
        self.derivedReadPath = derivedReadPath
        self.ingredientReadPath = ingredientReadPath
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
        if let derivedReadPath {
            lines.append("derived_read_path: \(derivedReadPath)")
        }
        if let ingredientReadPath {
            lines.append("ingredient_read_path: \(ingredientReadPath)")
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
            lines.append(parts.joined(separator: " | "))
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
    public let paths: PantryPathReport

    public init(
        recipe: RecipeDetail,
        features: RecipeDerivedFeatures,
        paths: PantryPaths,
        sourceReadPath: String = "direct-source",
        derivedReadPath: String = "sidecar-derived"
    ) {
        self.command = "recipes features"
        self.sourceReadPath = sourceReadPath
        self.derivedReadPath = derivedReadPath
        self.recipe = recipe
        self.features = features
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(recipe.name)",
            "source_read_path: \(sourceReadPath)",
            "derived_read_path: \(derivedReadPath)",
            "uid: \(recipe.uid)",
        ]

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

        switch features.sourceHashMatches(recipe.remoteHash) {
        case .some(true):
            lines.append("derived_source_hash_matches: yes")
        case .some(false):
            lines.append("derived_source_hash_matches: no")
        case .none:
            lines.append("derived_source_hash_matches: unknown")
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
    public let paths: PantryPathReport

    public init(
        recipe: RecipeDetail,
        ingredientIndex: RecipeIngredientIndex?,
        paths: PantryPaths,
        sourceReadPath: String = "direct-source",
        ingredientReadPath: String = "sidecar-ingredient-index"
    ) {
        self.command = "recipes ingredients"
        self.sourceReadPath = sourceReadPath
        self.ingredientReadPath = ingredientReadPath
        self.recipe = recipe
        self.ingredientIndex = ingredientIndex
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(recipe.name)",
            "source_read_path: \(sourceReadPath)",
            "ingredient_read_path: \(ingredientReadPath)",
            "uid: \(recipe.uid)",
        ]

        if !recipe.categories.isEmpty {
            lines.append("categories: \(recipe.categories.joined(separator: ", "))")
        }

        if let sourceName = recipe.sourceName, !sourceName.isEmpty {
            lines.append("source_name: \(sourceName)")
        }

        if let ingredientIndex {
            lines.append("derived_at: \(renderedTimestamp(ingredientIndex.derivedAt))")

            switch ingredientIndex.sourceHashMatches(recipe.remoteHash) {
            case .some(true):
                lines.append("derived_source_hash_matches: yes")
            case .some(false):
                lines.append("derived_source_hash_matches: no")
            case .none:
                lines.append("derived_source_hash_matches: unknown")
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
